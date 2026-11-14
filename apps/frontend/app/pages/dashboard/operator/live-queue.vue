<script setup lang="ts">
import { Activity, MessageCircle, RefreshCw, Search } from 'lucide-vue-next'
import { Badge } from '@/components/ui/badge'
import { Button } from '@/components/ui/button'
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card'
import { Input } from '@/components/ui/input'
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from '@/components/ui/select'

definePageMeta({ layout: 'dashboard' })

const activeStatuses = ['pending', 'approved', 'waiting_in_yard', 'called_to_dock', 'unloading'] as const
type QueueStatus = typeof activeStatuses[number]
type QueueFilter = 'all' | QueueStatus
type QueueRecord = {
  id: string
  queue_number: string
  driver_name: string
  driver_phone: string
  license_plate: string
  status: QueueStatus
  current_node_id: string | null
  assigned_dock_id: string | null
  vendor: { name: string } | null
}
type MapNodeRecord = {
  id: string
  name: string
  node_type: 'gate' | 'holding_yard' | 'dock' | 'mess' | 'meeting_room'
}
type YardQueueRecord = Pick<QueueRecord, 'id' | 'status' | 'current_node_id' | 'assigned_dock_id'>

const pageSize = 20
const inYardStatuses: QueueStatus[] = ['waiting_in_yard', 'called_to_dock', 'unloading']
const dockOccupancyStatuses = new Set<QueueStatus>(['called_to_dock', 'unloading'])
const queueStatusLabels: Record<QueueStatus, string> = {
  pending: 'Pending approval',
  approved: 'Approved',
  waiting_in_yard: 'Waiting in yard',
  called_to_dock: 'Called to dock',
  unloading: 'Unloading',
}

const supabase = useSupabaseClient()
const queues = ref<QueueRecord[]>([])
const yardQueues = ref<YardQueueRecord[]>([])
const mapNodes = ref<MapNodeRecord[]>([])
const selectedDockByQueue = ref<Record<string, string>>({})
const queueActionIds = ref<string[]>([])
const queueActionError = ref('')
const plantLocation = ref('')
const isLoading = ref(true)
const isRefreshing = ref(false)
const pageError = ref('')
const realtimeStatus = ref('Connecting')
const searchInput = ref('')
const appliedSearch = ref('')
const statusFilter = ref<QueueFilter>('all')
const pageNumber = ref(1)
const totalCount = ref(0)
let queueChannel: ReturnType<typeof supabase.channel> | undefined

const activeDocks = computed(() => mapNodes.value.filter(node => node.node_type === 'dock'))
const occupiedDockIds = computed(() => {
  const dockIds = new Set(activeDocks.value.map(dock => dock.id))
  return new Set(
    yardQueues.value
      .filter(queue => dockOccupancyStatuses.has(queue.status))
      .map(queue => queue.assigned_dock_id ?? queue.current_node_id)
      .filter((id): id is string => Boolean(id) && dockIds.has(id)),
  )
})
const pageCount = computed(() => Math.max(Math.ceil(totalCount.value / pageSize), 1))

function getErrorMessage(error: unknown, fallback = 'Unable to load the live vehicle queue.') {
  if (error instanceof Error) return error.message
  if (typeof error === 'object' && error !== null && 'message' in error && typeof error.message === 'string') {
    return error.message
  }
  return fallback
}

function reportPageError(error: unknown) {
  console.error('Unable to load live vehicle queue', error)
  pageError.value = getErrorMessage(error)
}

function isQueueStatus(value: string): value is QueueStatus {
  return activeStatuses.some(status => status === value)
}

function handleStatusChange(value: unknown) {
  statusFilter.value = value === 'all'
    ? 'all'
    : typeof value === 'string' && isQueueStatus(value)
      ? value
      : 'all'
  pageNumber.value = 1
  void loadLiveData()
}

function applySearch() {
  appliedSearch.value = searchInput.value.trim()
  pageNumber.value = 1
  void loadLiveData()
}

function getSelectedDockId(queue: QueueRecord) {
  return selectedDockByQueue.value[queue.id] ?? queue.assigned_dock_id ?? ''
}

function getQueueLocation(queue: Pick<QueueRecord, 'current_node_id' | 'assigned_dock_id'>) {
  const nodeId = queue.current_node_id ?? queue.assigned_dock_id
  return mapNodes.value.find(node => node.id === nodeId)?.name ?? 'Unassigned'
}

function getWhatsAppUrl(phone: string) {
  const digits = phone.replace(/\D/g, '')
  const internationalNumber = digits.startsWith('0') ? `62${digits.slice(1)}` : digits
  return internationalNumber ? `https://wa.me/${internationalNumber}` : ''
}

async function loadYardQueues(currentPlant: string): Promise<YardQueueRecord[]> {
  const result: YardQueueRecord[] = []
  const batchSize = 1000
  let offset = 0

  while (true) {
    const { data, error } = await supabase
      .from('logistics_queues')
      .select('id, status, current_node_id, assigned_dock_id')
      .eq('plant_location', currentPlant)
      .in('status', inYardStatuses)
      .order('id', { ascending: true })
      .range(offset, offset + batchSize - 1)

    if (error) throw error

    const page = data ?? []
    result.push(...page)
    if (page.length < batchSize) return result
    offset += batchSize
  }
}

async function loadLiveData() {
  if (!plantLocation.value) return

  isLoading.value = true
  pageError.value = ''

  try {
    let queueQuery = supabase
      .from('logistics_queues')
      .select('id, queue_number, driver_name, driver_phone, license_plate, status, current_node_id, assigned_dock_id, vendor:vendors(name)', { count: 'exact' })
      .eq('plant_location', plantLocation.value)
      .in('status', [...activeStatuses])
      .order('created_at', { ascending: false })
      .range((pageNumber.value - 1) * pageSize, pageNumber.value * pageSize - 1)

    if (statusFilter.value !== 'all') {
      queueQuery = queueQuery.eq('status', statusFilter.value)
    }
    if (appliedSearch.value) {
      queueQuery = queueQuery.ilike('license_plate', `%${appliedSearch.value}%`)
    }

    const [queueResult, nodeResult, yardQueueResult] = await Promise.all([
      queueQuery,
      supabase
        .from('map_nodes')
        .select('id, name, node_type')
        .eq('plant_location', plantLocation.value)
        .eq('is_active', true)
        .order('name', { ascending: true }),
      loadYardQueues(plantLocation.value),
    ])

    if (queueResult.error) throw queueResult.error
    if (queueResult.count === null) throw new Error('Queue count is unavailable.')
    if (nodeResult.error) throw nodeResult.error

    queues.value = queueResult.data ?? []
    totalCount.value = queueResult.count
    mapNodes.value = nodeResult.data ?? []
    yardQueues.value = yardQueueResult

    const lastPage = Math.max(Math.ceil(totalCount.value / pageSize), 1)
    if (pageNumber.value > lastPage) {
      pageNumber.value = lastPage
      await loadLiveData()
    }
  } catch (error) {
    reportPageError(error)
  } finally {
    isLoading.value = false
  }
}

async function loadPlantContext() {
  try {
    const { data: authData, error: authError } = await supabase.auth.getUser()
    if (authError) throw authError
    if (!authData.user) throw new Error('Your session could not be verified. Please sign in again.')

    const { data: profile, error: profileError } = await supabase
      .from('profiles')
      .select('plant_location')
      .eq('id', authData.user.id)
      .single()

    if (profileError) throw profileError
    if (typeof profile.plant_location !== 'string' || !profile.plant_location.trim()) {
      throw new Error('Plant location is missing from your profile. Contact an administrator.')
    }

    plantLocation.value = profile.plant_location.trim()
    await loadLiveData()
    if (!pageError.value) subscribeToQueueChanges()
  } catch (error) {
    reportPageError(error)
  } finally {
    isLoading.value = false
  }
}

function subscribeToQueueChanges() {
  if (queueChannel) return

  const topic = `operator-live-queue:${plantLocation.value}`
  queueChannel = supabase.channel(topic)
  queueChannel
    .on('postgres_changes', {
      event: '*',
      schema: 'public',
      table: 'logistics_queues',
      filter: `plant_location=eq.${plantLocation.value}`,
    }, () => {
      void loadLiveData()
    })
    .subscribe((status, error) => {
      if (status === 'SUBSCRIBED') {
        realtimeStatus.value = 'Live'
      } else if (status === 'CHANNEL_ERROR' || status === 'TIMED_OUT' || status === 'CLOSED') {
        realtimeStatus.value = 'Offline'
        if (status !== 'CLOSED') console.error('Live queue realtime connection failed', error ?? status)
      } else {
        realtimeStatus.value = 'Connecting'
      }
    })
}

async function refreshData() {
  if (isRefreshing.value) return
  isRefreshing.value = true
  try {
    await loadLiveData()
  } finally {
    isRefreshing.value = false
  }
}

async function callDriver(queue: QueueRecord) {
  if (queue.status !== 'waiting_in_yard' && queue.status !== 'called_to_dock') return

  const dockId = getSelectedDockId(queue)
  if (!dockId || !activeDocks.value.some(dock => dock.id === dockId)) {
    queueActionError.value = 'Select an active dock before calling the driver.'
    return
  }
  const dockInUseByAnotherQueue = yardQueues.value.some((yardQueue) => {
    if (yardQueue.id === queue.id || !dockOccupancyStatuses.has(yardQueue.status)) return false
    return (yardQueue.assigned_dock_id ?? yardQueue.current_node_id) === dockId
  })
  if (dockInUseByAnotherQueue) {
    queueActionError.value = 'The selected dock is already occupied. Choose another dock.'
    return
  }

  queueActionError.value = ''
  queueActionIds.value = [...queueActionIds.value, queue.id]

  try {
    const { data, error } = await supabase
      .from('logistics_queues')
      .update({
        assigned_dock_id: dockId,
        status: 'called_to_dock',
        updated_at: new Date().toISOString(),
      })
      .eq('id', queue.id)
      .select('id')
      .maybeSingle()

    if (error) throw error
    if (!data) throw new Error('Queue entry could not be updated. Refresh and try again.')

    queues.value = queues.value.map(queueEntry => (
      queueEntry.id === queue.id
        ? { ...queueEntry, assigned_dock_id: dockId, status: 'called_to_dock' }
        : queueEntry
    ))
    yardQueues.value = yardQueues.value.map(yardQueue => (
      yardQueue.id === queue.id
        ? { ...yardQueue, assigned_dock_id: dockId, status: 'called_to_dock' }
        : yardQueue
    ))
    await loadLiveData()
  } catch (error) {
    console.error('Unable to call logistics queue driver', error)
    queueActionError.value = getErrorMessage(error, 'Unable to call the driver.')
  } finally {
    queueActionIds.value = queueActionIds.value.filter(id => id !== queue.id)
  }
}

async function updateUnloadingStatus(queue: QueueRecord) {
  if (queue.status !== 'called_to_dock' && queue.status !== 'unloading') return

  const nextStatus = queue.status === 'called_to_dock' ? 'unloading' : 'completed'
  const updatedAt = new Date().toISOString()
  queueActionError.value = ''
  queueActionIds.value = [...queueActionIds.value, queue.id]

  try {
    const update = nextStatus === 'completed'
      ? { status: nextStatus, completed_at: updatedAt, updated_at: updatedAt }
      : {
          status: nextStatus,
          current_node_id: queue.assigned_dock_id ?? queue.current_node_id,
          unloading_started_at: updatedAt,
          updated_at: updatedAt,
        }
    const { data, error } = await supabase
      .from('logistics_queues')
      .update(update)
      .eq('id', queue.id)
      .select('id')
      .maybeSingle()

    if (error) throw error
    if (!data) throw new Error('Queue entry could not be updated. Refresh and try again.')

    if (nextStatus === 'completed') {
      queues.value = queues.value.filter(queueEntry => queueEntry.id !== queue.id)
      yardQueues.value = yardQueues.value.filter(yardQueue => yardQueue.id !== queue.id)
      totalCount.value = Math.max(totalCount.value - 1, 0)
    } else {
      queues.value = queues.value.map(queueEntry => (
        queueEntry.id === queue.id
          ? { ...queueEntry, status: nextStatus }
          : queueEntry
      ))
      yardQueues.value = yardQueues.value.map(yardQueue => (
        yardQueue.id === queue.id
          ? { ...yardQueue, status: nextStatus }
          : yardQueue
      ))
    }

    await loadLiveData()
  } catch (error) {
    console.error('Unable to update logistics queue unloading status', error)
    queueActionError.value = getErrorMessage(error, 'Unable to update the vehicle status.')
  } finally {
    queueActionIds.value = queueActionIds.value.filter(id => id !== queue.id)
  }
}

function changePage(nextPage: number) {
  if (nextPage < 1 || nextPage > pageCount.value || nextPage === pageNumber.value) return
  pageNumber.value = nextPage
  void loadLiveData()
}

onMounted(loadPlantContext)

onUnmounted(() => {
  if (queueChannel) void supabase.removeChannel(queueChannel)
})
</script>

<template>
  <div class="space-y-6">
    <div class="flex flex-wrap items-end justify-between gap-4">
      <div>
        <p class="text-sm text-muted-foreground">Yard Operations<span v-if="plantLocation"> · {{ plantLocation }}</span></p>
        <h1 class="text-3xl font-semibold tracking-tight">Live vehicle queue</h1>
      </div>
      <Button variant="outline" :disabled="isLoading || isRefreshing" @click="refreshData">
        <RefreshCw class="size-4" :class="isRefreshing ? 'animate-spin' : ''" />
        Refresh
      </Button>
    </div>

    <p v-if="pageError" role="alert" class="rounded-lg border border-red-500/20 bg-red-500/10 px-4 py-3 text-sm text-red-500">
      {{ pageError }}
    </p>

    <Card>
      <CardHeader>
        <div class="flex flex-wrap items-start justify-between gap-3">
          <div>
            <CardTitle>All active vehicles</CardTitle>
            <CardDescription class="mt-1">Search by license plate or filter by queue status.</CardDescription>
          </div>
          <Badge variant="secondary" class="gap-1.5">
            <Activity class="size-3" />
            {{ realtimeStatus }}
          </Badge>
        </div>
      </CardHeader>
      <CardContent class="space-y-6">
        <form class="flex flex-wrap items-center gap-2 rounded-lg border bg-muted/20 p-3 sm:p-4" @submit.prevent="applySearch">
          <div class="relative min-w-56 flex-1">
            <Search class="pointer-events-none absolute left-2.5 top-1/2 size-4 -translate-y-1/2 text-muted-foreground" />
            <Input v-model="searchInput" class="pl-9" aria-label="Search by license plate" placeholder="Search license plate" />
          </div>
          <Select :model-value="statusFilter" @update:model-value="handleStatusChange">
            <SelectTrigger class="w-48" aria-label="Filter by queue status">
              <SelectValue placeholder="All active statuses" />
            </SelectTrigger>
            <SelectContent>
              <SelectItem value="all">All active statuses</SelectItem>
              <SelectItem v-for="status in activeStatuses" :key="status" :value="status">
                {{ queueStatusLabels[status] }}
              </SelectItem>
            </SelectContent>
          </Select>
          <Button type="submit" variant="secondary" :disabled="isLoading">
            Search
          </Button>
        </form>

        <p v-if="queueActionError" role="alert" class="text-sm text-red-500">{{ queueActionError }}</p>
        <p v-if="isLoading" class="py-10 text-center text-sm text-muted-foreground">Loading queue…</p>
        <p v-else-if="pageError" class="py-10 text-center text-sm text-muted-foreground">Queue data is unavailable.</p>
        <p v-else-if="queues.length === 0" class="py-10 text-center text-sm text-muted-foreground">No active queue entries match these filters.</p>

        <div v-else class="space-y-3 pt-2">
          <article v-for="(queue, index) in queues" :key="queue.id" class="rounded-lg border bg-card p-4">
            <div class="flex flex-wrap items-start justify-between gap-3">
              <div class="flex items-center gap-3">
                <Badge variant="secondary" class="shrink-0">
                  No. {{ (pageNumber - 1) * pageSize + index + 1 }}
                </Badge>
                <div>
                  <p class="font-semibold">{{ queue.license_plate }}</p>
                  <p class="text-xs text-muted-foreground">{{ queue.queue_number }}</p>
                </div>
              </div>
              <Badge variant="outline">{{ queueStatusLabels[queue.status] }}</Badge>
            </div>

            <div class="mt-4 grid gap-4 sm:grid-cols-2 xl:grid-cols-4">
              <div>
                <p class="text-xs text-muted-foreground">Driver</p>
                <p class="mt-1 text-sm font-medium">{{ queue.driver_name }}</p>
              </div>
              <div>
                <p class="text-xs text-muted-foreground">Vendor</p>
                <p class="mt-1 text-sm font-medium">{{ queue.vendor?.name ?? '—' }}</p>
              </div>
              <div class="space-y-1">
                <p class="text-xs text-muted-foreground">Location / dock</p>
                <Select
                  v-if="queue.status === 'waiting_in_yard' || queue.status === 'called_to_dock'"
                  :model-value="getSelectedDockId(queue)"
                  :disabled="queueActionIds.includes(queue.id)"
                  @update:model-value="selectedDockByQueue[queue.id] = String($event)"
                >
                  <SelectTrigger class="w-full" :aria-label="`Select dock for ${queue.license_plate}`">
                    <SelectValue placeholder="Select dock" />
                  </SelectTrigger>
                  <SelectContent>
                    <SelectItem
                      v-for="dock in activeDocks"
                      :key="dock.id"
                      :value="dock.id"
                      :disabled="occupiedDockIds.has(dock.id) && getSelectedDockId(queue) !== dock.id"
                    >
                      {{ dock.name }}
                    </SelectItem>
                  </SelectContent>
                </Select>
                <p v-else class="mt-1 text-sm font-medium">{{ getQueueLocation(queue) }}</p>
              </div>
              <div class="flex flex-wrap items-end gap-2">
                <Button
                  v-if="queue.status === 'waiting_in_yard' || queue.status === 'called_to_dock'"
                  size="sm"
                  :disabled="queueActionIds.includes(queue.id) || !getSelectedDockId(queue)"
                  @click="callDriver(queue)"
                >
                  {{ queue.status === 'waiting_in_yard' ? 'Call' : 'Call again' }}
                </Button>
                <span v-else-if="queue.status === 'pending' || queue.status === 'approved'" class="self-center text-sm text-muted-foreground">No call action</span>
                <Button
                  v-if="queue.status === 'called_to_dock' || queue.status === 'unloading'"
                  size="sm"
                  variant="secondary"
                  :disabled="queueActionIds.includes(queue.id)"
                  @click="updateUnloadingStatus(queue)"
                >
                  {{ queue.status === 'called_to_dock' ? 'Bongkar' : 'Selesai bongkar' }}
                </Button>
                <Button v-if="getWhatsAppUrl(queue.driver_phone)" variant="outline" size="sm" as-child>
                  <a :href="getWhatsAppUrl(queue.driver_phone)" target="_blank" rel="noopener noreferrer">
                    <MessageCircle class="size-4" />
                    WhatsApp
                  </a>
                </Button>
                <span v-else class="text-sm text-muted-foreground">No phone</span>
              </div>
            </div>
          </article>
        </div>

        <div v-if="totalCount > 0 && !pageError" class="mt-4 flex flex-wrap items-center justify-between gap-3 px-2 pt-4 pb-2">
          <p class="text-sm text-muted-foreground">
            Showing {{ (pageNumber - 1) * pageSize + 1 }}–{{ Math.min(pageNumber * pageSize, totalCount) }} of {{ totalCount }} vehicles
          </p>
          <div class="flex gap-2">
            <Button variant="outline" size="sm" :disabled="isLoading || pageNumber <= 1" @click="changePage(pageNumber - 1)">
              Previous
            </Button>
            <Button variant="outline" size="sm" :disabled="isLoading || pageNumber >= pageCount" @click="changePage(pageNumber + 1)">
              Next
            </Button>
          </div>
        </div>
      </CardContent>
    </Card>
  </div>
</template>
