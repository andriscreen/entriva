<script setup lang="ts">
import { Activity, ArrowRight, MapPinned, RefreshCw, Truck } from 'lucide-vue-next'
import { Badge } from '@/components/ui/badge'
import { Button } from '@/components/ui/button'
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card'

definePageMeta({ layout: 'dashboard' })

type QueueStatus = 'waiting_in_yard' | 'called_to_dock' | 'unloading'
type QueueRecord = {
  id: string
  queue_number: string
  driver_name: string
  driver_phone: string
  license_plate: string
  checked_in_at: string | null
  status: QueueStatus
  current_node_id: string | null
  assigned_dock_id: string | null
  vendor: { name: string } | null
}
type MapNodeRecord = {
  id: string
  name: string
  node_type: 'gate' | 'holding_yard' | 'dock' | 'mess' | 'meeting_room'
  is_active: boolean
}
type YardQueueRecord = Pick<QueueRecord, 'id' | 'status' | 'current_node_id' | 'assigned_dock_id'>

const supabase = useSupabaseClient()
const queues = ref<QueueRecord[]>([])
const yardQueues = ref<YardQueueRecord[]>([])
const mapNodes = ref<MapNodeRecord[]>([])
const plantLocation = ref('')
const isLoading = ref(true)
const isRefreshing = ref(false)
const dashboardError = ref('')
const realtimeStatus = ref('Connecting')
const inYardStatuses = new Set<QueueStatus>(['waiting_in_yard', 'called_to_dock', 'unloading'])
const dockOccupancyStatuses = new Set<QueueStatus>(['called_to_dock', 'unloading'])
let dashboardChannel: ReturnType<typeof supabase.channel> | undefined

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
const availableDockCount = computed(() => Math.max(activeDocks.value.length - occupiedDockIds.value.size, 0))
const waitingForDockCount = computed(() => yardQueues.value.filter(queue => queue.status === 'waiting_in_yard').length)
const yardNodes = computed(() => (
  mapNodes.value
    .filter(node => node.node_type === 'dock')
    .map((node) => {
      const vehicleCount = yardQueues.value.filter(queue => getQueueNodeId(queue) === node.id).length

      return { ...node, vehicleCount }
    })
))
const unassignedYardVehicleCount = computed(() => {
  const yardNodeIds = new Set(yardNodes.value.map(node => node.id))
  return yardQueues.value.filter((queue) => {
    const nodeId = getQueueNodeId(queue)
    return !nodeId || !yardNodeIds.has(nodeId)
  }).length
})

const queueStatusLabels: Record<QueueStatus, string> = {
  waiting_in_yard: 'Waiting in yard',
  called_to_dock: 'Called to dock',
  unloading: 'Unloading',
}

function getErrorMessage(error: unknown) {
  if (error instanceof Error) return error.message
  if (typeof error === 'object' && error !== null && 'message' in error && typeof error.message === 'string') {
    return error.message
  }
  return 'Unable to load Command Center data.'
}

function reportDashboardError(error: unknown) {
  console.error('Unable to load operator Command Center data', error)
  dashboardError.value = getErrorMessage(error)
}

function getQueueNodeId(queue: Pick<QueueRecord, 'current_node_id' | 'assigned_dock_id'>) {
  return queue.current_node_id ?? queue.assigned_dock_id
}

async function loadPlantData() {
  const currentPlant = plantLocation.value
  if (!currentPlant) return

  const [queueResult, nodeResult, yardQueueResult] = await Promise.all([
    supabase
      .from('logistics_queues')
      .select('id, queue_number, driver_name, driver_phone, license_plate, checked_in_at, status, current_node_id, assigned_dock_id, vendor:vendors(name)')
      .eq('plant_location', currentPlant)
      .eq('status', 'waiting_in_yard')
      .order('checked_in_at', { ascending: true, nullsFirst: true })
      .order('created_at', { ascending: true })
      .order('id', { ascending: true })
      .limit(3),
    supabase
      .from('map_nodes')
      .select('id, name, node_type, is_active')
      .eq('plant_location', currentPlant)
      .eq('is_active', true)
      .order('name', { ascending: true }),
    loadYardQueues(currentPlant),
  ])

  if (queueResult.error) throw queueResult.error
  if (nodeResult.error) throw nodeResult.error

  queues.value = queueResult.data ?? []
  mapNodes.value = nodeResult.data ?? []
  yardQueues.value = yardQueueResult
}

async function loadYardQueues(currentPlant: string): Promise<YardQueueRecord[]> {
  const result: YardQueueRecord[] = []
  const pageSize = 1000
  let offset = 0

  while (true) {
    const { data, error } = await supabase
      .from('logistics_queues')
      .select('id, status, current_node_id, assigned_dock_id')
      .eq('plant_location', currentPlant)
      .in('status', [...inYardStatuses])
      .order('id', { ascending: true })
      .range(offset, offset + pageSize - 1)

    if (error) throw error

    const page = data ?? []
    result.push(...page)
    if (page.length < pageSize) return result
    offset += pageSize
  }
}

async function refreshData() {
  if (!plantLocation.value || isRefreshing.value) return

  isRefreshing.value = true
  try {
    await loadPlantData()
    dashboardError.value = ''
  } catch (error) {
    reportDashboardError(error)
  } finally {
    isRefreshing.value = false
  }
}

async function subscribeToPlantChanges() {
  if (dashboardChannel) return

  const topic = `operator-command-center:${plantLocation.value}`
  const existingChannel = supabase.getChannels().find(channel => channel.topic === `realtime:${topic}`)
  if (existingChannel) await supabase.removeChannel(existingChannel)

  const filter = `plant_location=eq.${plantLocation.value}`

  dashboardChannel = supabase.channel(topic)
  dashboardChannel
    .on('postgres_changes', {
      event: '*',
      schema: 'public',
      table: 'logistics_queues',
      filter,
    }, () => {
      void refreshData()
    })
    .on('postgres_changes', {
      event: '*',
      schema: 'public',
      table: 'map_nodes',
      filter,
    }, () => {
      void refreshData()
    })
    .subscribe((status, error) => {
      if (status === 'SUBSCRIBED') {
        realtimeStatus.value = 'Live'
      } else if (status === 'CHANNEL_ERROR' || status === 'TIMED_OUT' || status === 'CLOSED') {
        realtimeStatus.value = 'Offline'
        if (status !== 'CLOSED') {
          console.error('Command Center realtime connection failed', error ?? status)
        }
      } else {
        realtimeStatus.value = 'Connecting'
      }
    })
}

async function loadCommandCenter() {
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
    await refreshData()
    if (!dashboardError.value) await subscribeToPlantChanges()
  } catch (error) {
    reportDashboardError(error)
  } finally {
    isLoading.value = false
  }
}

function getQueueLocation(queue: QueueRecord) {
  const nodeId = getQueueNodeId(queue)
  return mapNodes.value.find(node => node.id === nodeId)?.name ?? 'Unassigned'
}

onMounted(loadCommandCenter)

onUnmounted(() => {
  if (dashboardChannel) void supabase.removeChannel(dashboardChannel)
})
</script>

<template>
  <div class="space-y-6">
    <div class="flex flex-wrap items-end justify-between gap-4">
      <div>
        <p class="text-sm text-muted-foreground">
          Yard control room<span v-if="plantLocation"> · {{ plantLocation }}</span>
        </p>
        <h1 class="text-3xl font-semibold tracking-tight">Command center</h1>
      </div>
      <Button
        variant="outline"
        :disabled="isLoading || isRefreshing || !plantLocation"
        @click="refreshData"
      >
        <RefreshCw class="size-4" :class="isRefreshing ? 'animate-spin' : ''" />
        Refresh data
      </Button>
    </div>

    <p
      v-if="dashboardError"
      role="alert"
      class="rounded-lg border border-red-500/20 bg-red-500/10 px-4 py-3 text-sm text-red-500"
    >
      {{ dashboardError }}
    </p>

    <section class="grid gap-4 md:grid-cols-3" aria-label="Yard status">
      <Card>
        <CardHeader>
          <CardDescription>Vehicles in yard</CardDescription>
          <CardTitle class="flex items-center gap-2 text-3xl">
            <Truck class="size-6 text-muted-foreground" />
            {{ isLoading ? '—' : dashboardError ? '—' : yardQueues.length }}
          </CardTitle>
        </CardHeader>
        <CardContent class="pt-0">
          <p class="text-xs text-muted-foreground">Waiting in yard, at dock, or unloading</p>
        </CardContent>
      </Card>

      <Card>
        <CardHeader>
          <CardDescription>Waiting for dock</CardDescription>
          <CardTitle class="text-3xl">
            {{ isLoading ? '—' : dashboardError ? '—' : waitingForDockCount }}
          </CardTitle>
        </CardHeader>
        <CardContent class="pt-0">
          <p class="text-xs text-muted-foreground">
            Queue status
          </p>
        </CardContent>
      </Card>

      <Card>
        <CardHeader>
          <CardDescription>Available docks</CardDescription>
          <CardTitle class="flex items-center gap-2 text-3xl">
            <MapPinned class="size-6 text-muted-foreground" />
            {{ isLoading ? '—' : dashboardError ? '—' : availableDockCount }}
          </CardTitle>
        </CardHeader>
        <CardContent class="pt-0">
          <p class="text-xs text-muted-foreground">
            {{ isLoading || dashboardError ? 'Active docks from Supabase' : `of ${activeDocks.length} active docks` }}
          </p>
        </CardContent>
      </Card>
    </section>

    <section class="grid gap-6 xl:grid-cols-[minmax(0,1fr)_18rem]">
      <Card>
        <CardHeader class="flex-row items-start justify-between space-y-0">
          <div>
            <CardTitle>Live vehicle queue</CardTitle>
            <CardDescription class="mt-1">Next 3 vehicles in gate check-in order (FIFO) for {{ plantLocation || 'your plant' }}.</CardDescription>
          </div>
          <div class="flex items-center gap-2">
            <Badge variant="secondary" class="gap-1.5">
              <Activity class="size-3" />
              {{ realtimeStatus }}
            </Badge>
            <Button as-child variant="outline" size="sm">
              <NuxtLink to="/dashboard/operator/live-queue">
                View all
                <ArrowRight class="size-4" />
              </NuxtLink>
            </Button>
          </div>
        </CardHeader>
        <CardContent class="space-y-3">
          <p v-if="isLoading" class="py-8 text-center text-sm text-muted-foreground">Loading queue…</p>
          <p v-else-if="dashboardError" class="py-8 text-center text-sm text-muted-foreground">Queue data is unavailable.</p>
          <p v-else-if="queues.length === 0" class="py-8 text-center text-sm text-muted-foreground">
            No vehicles have entered the yard yet. Vehicles appear after security scans their barcode at the gate.
          </p>
          <article
            v-for="queue in queues"
            v-else
            :key="queue.id"
            class="rounded-lg border bg-card p-4"
          >
            <div class="flex flex-wrap items-start justify-between gap-3">
              <div>
                <p class="font-semibold">{{ queue.license_plate }}</p>
                <p class="text-xs text-muted-foreground">{{ queue.queue_number }}</p>
              </div>
              <Badge variant="outline">{{ queueStatusLabels[queue.status] }}</Badge>
            </div>

            <div class="mt-4 grid gap-4 sm:grid-cols-2 xl:grid-cols-3">
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
                <p class="mt-1 text-sm font-medium">{{ getQueueLocation(queue) }}</p>
              </div>
            </div>
          </article>
        </CardContent>
      </Card>

      <Card>
        <CardHeader class="p-4 pb-2">
          <div class="flex items-center justify-between gap-2">
            <CardTitle class="flex items-center gap-2"><MapPinned class="size-4" /> Yard nodes</CardTitle>
            <Badge v-if="!isLoading && !dashboardError" variant="secondary">{{ yardQueues.length }} total</Badge>
          </div>
          <CardDescription>Vehicles in yard statuses, grouped by dock.</CardDescription>
        </CardHeader>
        <CardContent class="space-y-2 p-4 pt-2">
          <p v-if="isLoading" class="py-4 text-sm text-muted-foreground">Loading yard nodes…</p>
          <p v-else-if="dashboardError" class="py-4 text-sm text-muted-foreground">Yard node data is unavailable.</p>
          <p v-else-if="yardNodes.length === 0" class="py-4 text-sm text-muted-foreground">No active docks configured for this plant.</p>
          <Card v-for="node in yardNodes" v-else :key="node.id" size="sm" class="bg-muted/30">
            <CardContent class="flex items-center justify-between p-2.5">
              <div>
                <p class="font-medium">{{ node.name }}</p>
                <p class="text-xs text-muted-foreground">{{ node.node_type.replace('_', ' ') }}</p>
              </div>
              <Badge :variant="node.vehicleCount ? 'outline' : 'secondary'">
                {{ node.vehicleCount }} {{ node.vehicleCount === 1 ? 'vehicle' : 'vehicles' }}
              </Badge>
            </CardContent>
          </Card>
          <Card v-if="unassignedYardVehicleCount > 0 && !isLoading && !dashboardError" size="sm" class="border-dashed bg-muted/20">
            <CardContent class="flex items-center justify-between p-2.5">
              <div>
                <p class="font-medium">Unassigned / other</p>
                <p class="text-xs text-muted-foreground">No active yard node matches</p>
              </div>
              <Badge variant="outline">
                {{ unassignedYardVehicleCount }} {{ unassignedYardVehicleCount === 1 ? 'vehicle' : 'vehicles' }}
              </Badge>
            </CardContent>
          </Card>
        </CardContent>
      </Card>
    </section>
  </div>
</template>
