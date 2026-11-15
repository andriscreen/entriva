<script setup lang="ts">
import { History, LoaderCircle, RefreshCw, Search } from 'lucide-vue-next'
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
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from '@/components/ui/table'

definePageMeta({ layout: 'dashboard' })

const historyStatuses = [
  'approved',
  'waiting_in_yard',
  'called_to_dock',
  'unloading',
  'completed',
  'cancelled',
] as const
type HistoryStatus = typeof historyStatuses[number]
type HistoryFilter = 'all' | HistoryStatus
type HistoryQueueRecord = {
  id: string
  queue_number: string
  driver_name: string
  license_plate: string
  cargo_type: string
  status: HistoryStatus
  approved_by: string | null
  approved_by_name: string | null
  updated_at: string
  completed_at: string | null
  vendor: { name: string } | null
  approver: { full_name: string } | null
}

const pageSize = 20
const historyDateFormatter = new Intl.DateTimeFormat('id-ID', {
  dateStyle: 'medium',
  timeStyle: 'short',
})
const supabase = useSupabaseClient()
const plantLocation = ref('')
const historyQueues = ref<HistoryQueueRecord[]>([])
const searchInput = ref('')
const appliedSearch = ref('')
const statusFilter = ref<HistoryFilter>('all')
const pageNumber = ref(1)
const totalCount = ref(0)
const isLoading = ref(true)
const pageError = ref('')

const pageCount = computed(() => Math.max(Math.ceil(totalCount.value / pageSize), 1))
const statusLabels: Record<HistoryStatus, string> = {
  approved: 'Disetujui',
  waiting_in_yard: 'Menunggu di yard',
  called_to_dock: 'Dipanggil ke dock',
  unloading: 'Bongkar muatan',
  completed: 'Selesai',
  cancelled: 'Dibatalkan',
}

onMounted(() => {
  void loadPlantContext()
})

function getErrorMessage(error: unknown) {
  if (error instanceof Error) return error.message
  if (typeof error === 'object' && error !== null && 'message' in error && typeof error.message === 'string') {
    return error.message
  }
  return 'Riwayat kendaraan gagal dimuat.'
}

function formatHistoryDate(queue: HistoryQueueRecord) {
  const date = new Date(queue.completed_at ?? queue.updated_at)
  return Number.isNaN(date.getTime()) ? 'Tanggal tidak tersedia' : historyDateFormatter.format(date)
}

function escapeLikePattern(value: string) {
  return value.replace(/[\\%_]/g, '\\$&')
}

function quotePostgrestValue(value: string) {
  return `"${value.replace(/\\/g, '\\\\').replace(/"/g, '\\"')}"`
}

watch(statusFilter, () => {
  pageNumber.value = 1
  appliedSearch.value = searchInput.value.trim()
  void loadHistoryData()
})

async function loadPlantContext() {
  try {
    const { data: authData, error: authError } = await supabase.auth.getUser()
    if (authError) throw authError
    if (!authData.user) throw new Error('Sesi pengguna tidak ditemukan. Silakan masuk kembali.')

    const { data: profile, error: profileError } = await supabase
      .from('profiles')
      .select('plant_location')
      .eq('id', authData.user.id)
      .single()

    if (profileError) throw profileError
    if (typeof profile.plant_location !== 'string' || !profile.plant_location.trim()) {
      throw new Error('Lokasi plant akun tidak ditemukan.')
    }

    plantLocation.value = profile.plant_location.trim()
    await loadHistoryData()
  } catch (error) {
    console.error('Unable to load admin logistics history', error)
    pageError.value = getErrorMessage(error)
  } finally {
    isLoading.value = false
  }
}

async function loadHistoryData() {
  if (!plantLocation.value) return

  isLoading.value = true
  pageError.value = ''

  try {
    const statuses: HistoryStatus[] = statusFilter.value === 'all'
      ? [...historyStatuses]
      : [statusFilter.value]

    let historyQuery = supabase
      .from('logistics_queues')
      .select('id, queue_number, driver_name, license_plate, cargo_type, status, approved_by, approved_by_name, updated_at, completed_at, vendor:vendors(name), approver:profiles!logistics_queues_approved_by_fkey(full_name)', { count: 'exact' })
      .eq('plant_location', plantLocation.value)
      .in('status', statuses)
      .order('updated_at', { ascending: false })
      .range((pageNumber.value - 1) * pageSize, pageNumber.value * pageSize - 1)

    if (appliedSearch.value) {
      const searchPattern = `%${escapeLikePattern(appliedSearch.value)}%`
      const { data: matchingVendors, error: vendorError } = await supabase
        .from('vendors')
        .select('id')
        .ilike('name', searchPattern)

      if (vendorError) throw vendorError

      const vendorIds = (matchingVendors ?? []).map(vendor => vendor.id)
      if (vendorIds.length > 0) {
        historyQuery = historyQuery.or(
          `license_plate.ilike.${quotePostgrestValue(searchPattern)},vendor_id.in.(${vendorIds.join(',')})`,
        )
      } else {
        historyQuery = historyQuery.ilike('license_plate', searchPattern)
      }
    }

    const { data, count, error } = await historyQuery
    if (error) throw error
    if (count === null) throw new Error('Jumlah riwayat kendaraan tidak tersedia.')

    const lastPage = Math.max(Math.ceil(count / pageSize), 1)
    if (pageNumber.value > lastPage) {
      pageNumber.value = lastPage
      await loadHistoryData()
      return
    }

    historyQueues.value = data ?? []
    totalCount.value = count
  } catch (error) {
    console.error('Unable to load admin logistics history', error)
    pageError.value = getErrorMessage(error)
  } finally {
    isLoading.value = false
  }
}

function applyFilters() {
  appliedSearch.value = searchInput.value.trim()
  pageNumber.value = 1
  void loadHistoryData()
}

function changePage(nextPage: number) {
  if (isLoading.value || nextPage < 1 || nextPage > pageCount.value) return

  pageNumber.value = nextPage
  void loadHistoryData()
}
</script>

<template>
  <div class="space-y-6">
    <div class="flex flex-wrap items-end justify-between gap-4">
      <div>
        <p class="text-sm text-muted-foreground">
          Logistics operations<span v-if="plantLocation"> · {{ plantLocation }}</span>
        </p>
        <h1 class="text-3xl font-semibold tracking-tight">Driver history</h1>
      </div>
      <Button variant="outline" :disabled="isLoading" @click="loadHistoryData">
        <RefreshCw class="size-4" :class="isLoading ? 'animate-spin' : ''" />
        Refresh
      </Button>
    </div>

    <p
      v-if="pageError"
      role="alert"
      class="rounded-xl border border-red-500/20 bg-red-500/10 px-4 py-3 text-sm text-red-700 dark:text-red-300"
    >
      {{ pageError }}
    </p>

    <Card>
      <CardHeader>
        <div class="flex flex-wrap items-start justify-between gap-3">
          <div>
            <CardTitle class="flex items-center gap-2"><History class="size-5" /> Riwayat kendaraan</CardTitle>
            <CardDescription class="mt-1">
              Antrean yang sudah disetujui hingga selesai atau dibatalkan di {{ plantLocation || 'plant akun' }}.
            </CardDescription>
          </div>
          <Badge variant="secondary">{{ totalCount }} catatan</Badge>
        </div>
      </CardHeader>
      <CardContent class="space-y-4">
        <form class="flex flex-wrap items-center gap-2" @submit.prevent="applyFilters">
          <div class="relative min-w-56 flex-1">
            <Search class="pointer-events-none absolute left-2.5 top-1/2 size-4 -translate-y-1/2 text-muted-foreground" />
            <Input
              v-model="searchInput"
              class="pl-9"
              aria-label="Cari nomor kendaraan atau vendor"
              placeholder="Cari nomor kendaraan atau vendor"
            />
          </div>
          <Select v-model="statusFilter" :disabled="isLoading">
            <SelectTrigger class="w-48" aria-label="Filter status riwayat">
              <SelectValue placeholder="Semua status" />
            </SelectTrigger>
            <SelectContent>
              <SelectItem value="all">Semua status</SelectItem>
              <SelectItem value="approved">Disetujui</SelectItem>
              <SelectItem value="waiting_in_yard">Menunggu di yard</SelectItem>
              <SelectItem value="called_to_dock">Dipanggil ke dock</SelectItem>
              <SelectItem value="unloading">Bongkar muatan</SelectItem>
              <SelectItem value="completed">Selesai</SelectItem>
              <SelectItem value="cancelled">Dibatalkan</SelectItem>
            </SelectContent>
          </Select>
          <Button type="submit" variant="secondary" :disabled="isLoading">
            Cari
          </Button>
        </form>

        <Table>
          <TableHeader>
            <TableRow>
              <TableHead>Nomor antrean</TableHead>
              <TableHead>Kendaraan / pengemudi</TableHead>
              <TableHead>Vendor / muatan</TableHead>
              <TableHead>Status</TableHead>
              <TableHead>Disetujui oleh</TableHead>
              <TableHead>Waktu</TableHead>
            </TableRow>
          </TableHeader>
          <TableBody>
            <TableRow v-if="isLoading">
              <TableCell colspan="6" class="py-8 text-center text-muted-foreground">
                <LoaderCircle class="mr-2 inline size-4 animate-spin" />
                Memuat riwayat...
              </TableCell>
            </TableRow>
            <TableRow v-else-if="pageError">
              <TableCell colspan="6" class="py-8 text-center text-muted-foreground">
                Riwayat tidak dapat ditampilkan.
              </TableCell>
            </TableRow>
            <TableRow v-else-if="historyQueues.length === 0">
              <TableCell colspan="6" class="py-8 text-center text-muted-foreground">
                Tidak ada catatan riwayat yang cocok.
              </TableCell>
            </TableRow>
            <TableRow v-for="queue in historyQueues" v-else :key="queue.id">
              <TableCell class="font-medium">{{ queue.queue_number }}</TableCell>
              <TableCell>
                <span class="block font-medium">{{ queue.license_plate }}</span>
                <span class="text-xs text-muted-foreground">{{ queue.driver_name }}</span>
              </TableCell>
              <TableCell>
                <span class="block">{{ queue.vendor?.name ?? 'Vendor tidak tersedia' }}</span>
                <span class="text-xs text-muted-foreground">{{ queue.cargo_type }}</span>
              </TableCell>
              <TableCell>
                <Badge
                  :variant="queue.status === 'completed'
                    ? 'secondary'
                    : queue.status === 'cancelled'
                      ? 'destructive'
                      : 'outline'"
                >
                  {{ statusLabels[queue.status] }}
                </Badge>
              </TableCell>
              <TableCell>
                <span v-if="queue.approved_by_name || queue.approved_by">
                  {{ queue.approved_by_name ?? queue.approver?.full_name ?? 'Nama approver tidak tersedia' }}
                </span>
                <span v-else class="text-muted-foreground">—</span>
              </TableCell>
              <TableCell>{{ formatHistoryDate(queue) }}</TableCell>
            </TableRow>
          </TableBody>
        </Table>

        <div
          v-if="totalCount > 0 && !pageError"
          class="flex flex-wrap items-center justify-between gap-3 border-t pt-4"
        >
          <p class="text-sm text-muted-foreground">
            Menampilkan {{ (pageNumber - 1) * pageSize + 1 }}–{{ Math.min(pageNumber * pageSize, totalCount) }}
            dari {{ totalCount }} catatan
          </p>
          <div class="flex gap-2">
            <Button
              variant="outline"
              size="sm"
              :disabled="isLoading || pageNumber <= 1"
              @click="changePage(pageNumber - 1)"
            >
              Sebelumnya
            </Button>
            <Button
              variant="outline"
              size="sm"
              :disabled="isLoading || pageNumber >= pageCount"
              @click="changePage(pageNumber + 1)"
            >
              Berikutnya
            </Button>
          </div>
        </div>
      </CardContent>
    </Card>
  </div>
</template>
