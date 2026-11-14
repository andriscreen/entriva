<script setup lang="ts">
import { History, RefreshCw, Search } from 'lucide-vue-next'
import { Badge } from '@/components/ui/badge'
import { Button } from '@/components/ui/button'
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card'
import { Input } from '@/components/ui/input'

definePageMeta({ layout: 'dashboard' })

type CompletedQueueRecord = {
  id: string
  queue_number: string
  driver_name: string
  license_plate: string
  cargo_type: string
  unloading_started_at: string | null
  completed_at: string | null
  vendor: { name: string } | null
}

const pageSize = 20
const completedAtFormatter = new Intl.DateTimeFormat('id-ID', {
  dateStyle: 'medium',
  timeStyle: 'short',
})
const supabase = useSupabaseClient()
const completedQueues = ref<CompletedQueueRecord[]>([])
const plantLocation = ref('')
const searchInput = ref('')
const appliedSearch = ref('')
const pageNumber = ref(1)
const totalCount = ref(0)
const isLoading = ref(true)
const isRefreshing = ref(false)
const pageError = ref('')
let historyChannel: ReturnType<typeof supabase.channel> | undefined

const pageCount = computed(() => Math.max(Math.ceil(totalCount.value / pageSize), 1))

function getErrorMessage(error: unknown) {
  if (error instanceof Error) return error.message
  if (typeof error === 'object' && error !== null && 'message' in error && typeof error.message === 'string') {
    return error.message
  }
  return 'Unable to load queue history.'
}

function reportPageError(error: unknown) {
  console.error('Unable to load operator queue history', error)
  pageError.value = getErrorMessage(error)
}

function formatCompletedAt(value: string | null) {
  if (!value) return 'Completion time not recorded'
  const date = new Date(value)
  return Number.isNaN(date.getTime()) ? 'Invalid completion time' : completedAtFormatter.format(date)
}

function formatUnloadingDuration(startedAt: string | null, completedAt: string | null) {
  if (!startedAt || !completedAt) return 'Not recorded'

  const durationMs = new Date(completedAt).getTime() - new Date(startedAt).getTime()
  if (!Number.isFinite(durationMs) || durationMs < 0) return 'Invalid duration'

  const totalMinutes = Math.floor(durationMs / 60_000)
  if (totalMinutes === 0) return '<1m'

  const days = Math.floor(totalMinutes / 1440)
  const hours = Math.floor((totalMinutes % 1440) / 60)
  const minutes = totalMinutes % 60

  if (days > 0) return `${days}d ${hours}h ${minutes}m`
  if (hours > 0) return `${hours}h ${minutes}m`
  return `${minutes}m`
}

async function loadHistoryData() {
  if (!plantLocation.value) return

  isLoading.value = true
  pageError.value = ''

  try {
    let historyQuery = supabase
      .from('logistics_queues')
      .select('id, queue_number, driver_name, license_plate, cargo_type, unloading_started_at, completed_at, vendor:vendors(name)', { count: 'exact' })
      .eq('plant_location', plantLocation.value)
      .eq('status', 'completed')
      .order('completed_at', { ascending: false, nullsFirst: false })
      .order('created_at', { ascending: false })
      .range((pageNumber.value - 1) * pageSize, pageNumber.value * pageSize - 1)

    if (appliedSearch.value) {
      historyQuery = historyQuery.ilike('license_plate', `%${appliedSearch.value}%`)
    }

    const { data, count, error } = await historyQuery
    if (error) throw error
    if (count === null) throw new Error('Queue history count is unavailable.')

    completedQueues.value = data ?? []
    totalCount.value = count

    const lastPage = Math.max(Math.ceil(totalCount.value / pageSize), 1)
    if (pageNumber.value > lastPage) {
      pageNumber.value = lastPage
      await loadHistoryData()
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
    await loadHistoryData()
    if (!pageError.value) subscribeToHistoryChanges()
  } catch (error) {
    reportPageError(error)
  } finally {
    isLoading.value = false
  }
}

function subscribeToHistoryChanges() {
  if (historyChannel) return

  historyChannel = supabase.channel(`operator-queue-history:${plantLocation.value}`)
  historyChannel
    .on('postgres_changes', {
      event: '*',
      schema: 'public',
      table: 'logistics_queues',
      filter: `plant_location=eq.${plantLocation.value}`,
    }, () => {
      void loadHistoryData()
    })
    .subscribe((status, error) => {
      if (status !== 'SUBSCRIBED' && status !== 'CLOSED') {
        console.error('Queue history realtime connection failed', error ?? status)
      }
    })
}

function applySearch() {
  appliedSearch.value = searchInput.value.trim()
  pageNumber.value = 1
  void loadHistoryData()
}

async function refreshData() {
  if (isRefreshing.value) return
  isRefreshing.value = true
  try {
    await loadHistoryData()
  } finally {
    isRefreshing.value = false
  }
}

function changePage(nextPage: number) {
  if (nextPage < 1 || nextPage > pageCount.value || nextPage === pageNumber.value) return
  pageNumber.value = nextPage
  void loadHistoryData()
}

onMounted(loadPlantContext)

onUnmounted(() => {
  if (historyChannel) void supabase.removeChannel(historyChannel)
})
</script>

<template>
  <div class="space-y-6">
    <div class="flex flex-wrap items-end justify-between gap-4">
      <div>
        <p class="text-sm text-muted-foreground">Yard Operations<span v-if="plantLocation"> · {{ plantLocation }}</span></p>
        <h1 class="text-3xl font-semibold tracking-tight">Queue History</h1>
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
            <CardTitle class="flex items-center gap-2"><History class="size-5" /> Completed vehicles</CardTitle>
            <CardDescription class="mt-1">Completed queue records for {{ plantLocation || 'your plant' }}.</CardDescription>
          </div>
          <Badge variant="secondary">{{ totalCount }} completed</Badge>
        </div>
      </CardHeader>
      <CardContent class="space-y-4">
        <form class="flex flex-wrap items-center gap-2" @submit.prevent="applySearch">
          <div class="relative min-w-56 flex-1">
            <Search class="pointer-events-none absolute left-2.5 top-1/2 size-4 -translate-y-1/2 text-muted-foreground" />
            <Input v-model="searchInput" class="pl-9" aria-label="Search by license plate" placeholder="Search license plate" />
          </div>
          <Button type="submit" variant="secondary" :disabled="isLoading">
            Search
          </Button>
        </form>

        <p v-if="isLoading" class="py-10 text-center text-sm text-muted-foreground">Loading queue history…</p>
        <p v-else-if="pageError" class="py-10 text-center text-sm text-muted-foreground">Queue history is unavailable.</p>
        <p v-else-if="completedQueues.length === 0" class="py-10 text-center text-sm text-muted-foreground">No completed vehicles match this search.</p>

        <div v-else class="space-y-3">
          <article v-for="queue in completedQueues" :key="queue.id" class="rounded-lg border bg-card p-4">
            <div class="flex flex-wrap items-start justify-between gap-3">
              <div>
                <p class="font-semibold">{{ queue.license_plate }}</p>
                <p class="text-xs text-muted-foreground">{{ queue.queue_number }}</p>
              </div>
              <Badge variant="secondary">Completed</Badge>
            </div>
            <div class="mt-4 grid gap-4 sm:grid-cols-2 xl:grid-cols-5">
              <div>
                <p class="text-xs text-muted-foreground">Driver</p>
                <p class="mt-1 text-sm font-medium">{{ queue.driver_name }}</p>
              </div>
              <div>
                <p class="text-xs text-muted-foreground">Vendor</p>
                <p class="mt-1 text-sm font-medium">{{ queue.vendor?.name ?? '—' }}</p>
              </div>
              <div>
                <p class="text-xs text-muted-foreground">Cargo</p>
                <p class="mt-1 text-sm font-medium">{{ queue.cargo_type }}</p>
              </div>
              <div>
                <p class="text-xs text-muted-foreground">Completed at</p>
                <p class="mt-1 text-sm font-medium">{{ formatCompletedAt(queue.completed_at) }}</p>
              </div>
              <div>
                <p class="text-xs text-muted-foreground">Unloading duration</p>
                <p class="mt-1 text-sm font-medium">
                  {{ formatUnloadingDuration(queue.unloading_started_at, queue.completed_at) }}
                </p>
              </div>
            </div>
          </article>
        </div>

        <div v-if="totalCount > 0 && !pageError" class="flex flex-wrap items-center justify-between gap-3 pt-4">
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
