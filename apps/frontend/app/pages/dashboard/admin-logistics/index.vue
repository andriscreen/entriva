<script setup lang="ts">
import { Check, CheckCircle2, Clock3, Dock, LoaderCircle, RefreshCw } from 'lucide-vue-next'
import { Badge } from '@/components/ui/badge'
import { Button } from '@/components/ui/button'
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card'
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from '@/components/ui/dialog'
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from '@/components/ui/table'

definePageMeta({ layout: 'dashboard' })

const pageSize = 20

type PendingQueueRecord = {
  id: string
  queue_number: string
  driver_name: string
  license_plate: string
  cargo_type: string
  created_at: string
  vendor: { name: string } | null
}

type DockRecord = {
  id: string
  name: string
}

type DockQueueRecord = {
  queue_number: string
  license_plate: string
  current_node_id: string | null
  assigned_dock_id: string | null
}

const supabase = useSupabaseClient()
const plantLocation = ref('')
const pendingApprovals = ref(0)
const arrivalsToday = ref(0)
const pendingQueues = ref<PendingQueueRecord[]>([])
const pageNumber = ref(1)
const docks = ref<DockRecord[]>([])
const activeDockQueues = ref<DockQueueRecord[]>([])
const isLoading = ref(true)
const isRefreshing = ref(false)
const processingQueueId = ref<string | null>(null)
const dashboardError = ref('')
const queueActionError = ref('')
const queueToCancel = ref<PendingQueueRecord | null>(null)
const isCancelDialogOpen = ref(false)
const { showSuccess } = useSuccessModal()

const pageCount = computed(() => Math.max(Math.ceil(pendingApprovals.value / pageSize), 1))
const dockQueueById = computed(() => {
  const queuesByDockId = new Map<string, DockQueueRecord>()

  for (const queue of activeDockQueues.value) {
    const dockId = queue.assigned_dock_id ?? queue.current_node_id
    if (dockId && !queuesByDockId.has(dockId)) queuesByDockId.set(dockId, queue)
  }

  return queuesByDockId
})
const occupiedDockCount = computed(() => (
  docks.value.filter(dock => dockQueueById.value.has(dock.id)).length
))
const availableDockCount = computed(() => Math.max(docks.value.length - occupiedDockCount.value, 0))
const dockOccupancy = computed(() => (
  docks.value.length ? Math.round((occupiedDockCount.value / docks.value.length) * 100) : 0
))

onMounted(() => {
  void loadDashboard()
})

function getErrorMessage(error: unknown) {
  if (error instanceof Error) return error.message
  if (typeof error === 'object' && error !== null && 'message' in error && typeof error.message === 'string') {
    return error.message
  }
  return 'Data dashboard admin logistik gagal dimuat.'
}

function formatArrivalTime(timestamp: string) {
  return new Date(timestamp).toLocaleTimeString('id-ID', {
    hour: '2-digit',
    minute: '2-digit',
  })
}

function changePage(nextPage: number) {
  if (isRefreshing.value || nextPage < 1 || nextPage > pageCount.value) return

  pageNumber.value = nextPage
  void loadDashboard()
}

async function loadDashboard() {
  if (isRefreshing.value) return

  isRefreshing.value = true
  dashboardError.value = ''
  queueActionError.value = ''

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

    const currentPlant = profile.plant_location.trim()
    const today = new Date()
    today.setHours(0, 0, 0, 0)

    const [queueResult, arrivalsResult, dockResult, dockQueueResult] = await Promise.all([
      supabase
        .from('logistics_queues')
        .select('id, queue_number, driver_name, license_plate, cargo_type, created_at, vendor:vendors(name)', { count: 'exact' })
        .eq('plant_location', currentPlant)
        .eq('status', 'pending')
        .order('created_at', { ascending: true })
        .range((pageNumber.value - 1) * pageSize, pageNumber.value * pageSize - 1),
      supabase
        .from('logistics_queues')
        .select('id', { count: 'exact', head: true })
        .eq('plant_location', currentPlant)
        .gte('created_at', today.toISOString()),
      supabase
        .from('map_nodes')
        .select('id, name')
        .eq('plant_location', currentPlant)
        .eq('node_type', 'dock')
        .eq('is_active', true)
        .order('name', { ascending: true }),
      supabase
        .from('logistics_queues')
        .select('queue_number, license_plate, current_node_id, assigned_dock_id')
        .eq('plant_location', currentPlant)
        .in('status', ['called_to_dock', 'unloading'])
        .order('updated_at', { ascending: false }),
    ])

    if (queueResult.error) throw queueResult.error
    if (arrivalsResult.error) throw arrivalsResult.error
    if (dockResult.error) throw dockResult.error
    if (dockQueueResult.error) throw dockQueueResult.error
    if (queueResult.count === null || arrivalsResult.count === null) {
      throw new Error('Jumlah antrean tidak tersedia.')
    }

    const lastPage = Math.max(Math.ceil(queueResult.count / pageSize), 1)
    let queuePage = queueResult.data ?? []
    if (pageNumber.value > lastPage) {
      pageNumber.value = lastPage
      const { data, error } = await supabase
        .from('logistics_queues')
        .select('id, queue_number, driver_name, license_plate, cargo_type, created_at, vendor:vendors(name)')
        .eq('plant_location', currentPlant)
        .eq('status', 'pending')
        .order('created_at', { ascending: true })
        .range((pageNumber.value - 1) * pageSize, pageNumber.value * pageSize - 1)

      if (error) throw error
      queuePage = data ?? []
    }

    plantLocation.value = currentPlant
    pendingApprovals.value = queueResult.count
    arrivalsToday.value = arrivalsResult.count
    pendingQueues.value = queuePage
    docks.value = dockResult.data ?? []
    activeDockQueues.value = dockQueueResult.data ?? []
  } catch (error) {
    console.error('Unable to load admin logistics dashboard data', error)
    dashboardError.value = getErrorMessage(error)
  } finally {
    isLoading.value = false
    isRefreshing.value = false
  }
}

async function approveDriver(queue: PendingQueueRecord) {
  if (processingQueueId.value) return

  processingQueueId.value = queue.id
  queueActionError.value = ''

  try {
    const { data: authData, error: authError } = await supabase.auth.getUser()
    if (authError) throw authError
    if (!authData.user) throw new Error('Sesi pengguna tidak ditemukan. Silakan masuk kembali.')

    const { data: approverProfile, error: approverProfileError } = await supabase
      .from('profiles')
      .select('full_name')
      .eq('id', authData.user.id)
      .single()

    if (approverProfileError) throw approverProfileError
    if (typeof approverProfile.full_name !== 'string' || !approverProfile.full_name.trim()) {
      throw new Error('Nama profil approver tidak ditemukan.')
    }

    const { data, error } = await supabase
      .from('logistics_queues')
      .update({
        status: 'approved',
        approved_by: authData.user.id,
        approved_by_name: approverProfile.full_name.trim(),
        updated_at: new Date().toISOString(),
      })
      .eq('id', queue.id)
      .eq('plant_location', plantLocation.value)
      .eq('status', 'pending')
      .select('id')
      .maybeSingle()

    if (error) throw error
    if (!data) throw new Error('Pengajuan sudah diproses atau tidak ditemukan. Muat ulang antrean.')

    showSuccess(`Pengajuan ${queue.queue_number} berhasil disetujui.`)
    await loadDashboard()
  } catch (error) {
    console.error('Unable to approve logistics queue', error)
    queueActionError.value = getErrorMessage(error)
  } finally {
    processingQueueId.value = null
  }
}

function requestCancel(queue: PendingQueueRecord) {
  queueToCancel.value = queue
  isCancelDialogOpen.value = true
}

function handleCancelDialogOpenChange(open: boolean) {
  isCancelDialogOpen.value = open
  if (!open && processingQueueId.value === null) {
    queueToCancel.value = null
    queueActionError.value = ''
  }
}

async function cancelDriver() {
  const queue = queueToCancel.value
  if (!queue || processingQueueId.value) return

  processingQueueId.value = queue.id
  queueActionError.value = ''

  try {
    const { data: authData, error: authError } = await supabase.auth.getUser()
    if (authError) throw authError
    if (!authData.user) throw new Error('Sesi pengguna tidak ditemukan. Silakan masuk kembali.')

    const { data, error } = await supabase
      .from('logistics_queues')
      .update({
        status: 'cancelled',
        updated_at: new Date().toISOString(),
      })
      .eq('id', queue.id)
      .eq('plant_location', plantLocation.value)
      .eq('status', 'pending')
      .select('id')
      .maybeSingle()

    if (error) throw error
    if (!data) throw new Error('Pengajuan sudah diproses atau tidak ditemukan. Muat ulang antrean.')

    isCancelDialogOpen.value = false
    queueToCancel.value = null
    showSuccess(`Pengajuan ${queue.queue_number} berhasil dibatalkan.`)
    await loadDashboard()
  } catch (error) {
    console.error('Unable to cancel logistics queue', error)
    queueActionError.value = getErrorMessage(error)
  } finally {
    processingQueueId.value = null
  }
}
</script>

<template>
  <div class="space-y-6">
    <div class="flex flex-wrap items-end justify-between gap-4">
      <div>
        <p class="text-sm text-muted-foreground">
          Logistics operations<span v-if="plantLocation"> · {{ plantLocation }}</span>
        </p>
        <h1 class="text-3xl font-semibold tracking-tight">Driver approval queue</h1>
      </div>
      <Button variant="outline" :disabled="isRefreshing || processingQueueId !== null" @click="loadDashboard">
        <LoaderCircle v-if="isRefreshing" class="size-4 animate-spin" />
        <RefreshCw v-else class="size-4" />
        Refresh data
      </Button>
    </div>

    <p
      v-if="dashboardError"
      role="alert"
      class="rounded-xl border border-red-500/20 bg-red-500/10 px-4 py-3 text-sm text-red-700 dark:text-red-300"
    >
      {{ dashboardError }}
    </p>
    <p
      v-if="queueActionError"
      role="alert"
      class="rounded-xl border border-red-500/20 bg-red-500/10 px-4 py-3 text-sm text-red-700 dark:text-red-300"
    >
      {{ queueActionError }}
    </p>

    <section class="grid gap-4 md:grid-cols-3" aria-label="Logistics metrics">
      <Card>
        <CardHeader>
          <CardDescription>Menunggu persetujuan</CardDescription>
          <CardTitle class="text-3xl">{{ isLoading || dashboardError ? '—' : pendingApprovals }}</CardTitle>
        </CardHeader>
        <CardContent class="pt-0">
          <p class="flex items-center gap-2 text-xs text-amber-500">
            <Clock3 class="size-3.5" />
            Antrean yang perlu ditinjau
          </p>
        </CardContent>
      </Card>
      <Card>
        <CardHeader>
          <CardDescription>Okupansi dock</CardDescription>
          <CardTitle class="text-3xl">{{ isLoading || dashboardError ? '—' : `${dockOccupancy}%` }}</CardTitle>
        </CardHeader>
        <CardContent class="pt-0">
          <p class="text-xs text-muted-foreground">
            {{ isLoading || dashboardError ? 'Memuat data dock...' : `${occupiedDockCount} dari ${docks.length} dock digunakan · ${availableDockCount} tersedia` }}
          </p>
        </CardContent>
      </Card>
      <Card>
        <CardHeader>
          <CardDescription>Kedatangan hari ini</CardDescription>
          <CardTitle class="text-3xl">{{ isLoading || dashboardError ? '—' : arrivalsToday }}</CardTitle>
        </CardHeader>
        <CardContent class="pt-0">
          <p class="flex items-center gap-2 text-xs text-emerald-600">
            <CheckCircle2 class="size-3.5" />
            Berdasarkan waktu pendaftaran
          </p>
        </CardContent>
      </Card>
    </section>

    <section class="grid gap-6 xl:grid-cols-[minmax(0,2fr)_minmax(15rem,0.7fr)]">
      <Card>
        <CardHeader>
          <CardTitle>Pengajuan kendaraan</CardTitle>
          <CardDescription>Permintaan akses yang menunggu persetujuan untuk plant ini.</CardDescription>
        </CardHeader>
        <CardContent>
          <Table>
            <TableHeader>
              <TableRow>
                <TableHead>Kendaraan</TableHead>
                <TableHead>Vendor / muatan</TableHead>
                <TableHead>Kedatangan</TableHead>
                <TableHead>Status</TableHead>
                <TableHead class="text-right">Tindakan</TableHead>
              </TableRow>
            </TableHeader>
            <TableBody>
              <TableRow v-if="isLoading">
                <TableCell colspan="5" class="py-8 text-center text-muted-foreground">
                  <LoaderCircle class="mr-2 inline size-4 animate-spin" />
                  Memuat antrean...
                </TableCell>
              </TableRow>
              <TableRow v-else-if="dashboardError">
                <TableCell colspan="5" class="py-8 text-center text-muted-foreground">
                  Antrean tidak dapat ditampilkan.
                </TableCell>
              </TableRow>
              <TableRow v-else-if="pendingQueues.length === 0">
                <TableCell colspan="5" class="py-8 text-center text-muted-foreground">
                  Tidak ada pengajuan kendaraan yang menunggu.
                </TableCell>
              </TableRow>
              <TableRow v-for="driver in pendingQueues" v-else :key="driver.id">
                <TableCell>
                  <span class="block font-medium">{{ driver.license_plate }}</span>
                  <span class="text-xs text-muted-foreground">{{ driver.driver_name }} · {{ driver.queue_number }}</span>
                </TableCell>
                <TableCell>
                  <span class="block">{{ driver.vendor?.name ?? 'Vendor tidak tersedia' }}</span>
                  <span class="text-xs text-muted-foreground">{{ driver.cargo_type }}</span>
                </TableCell>
                <TableCell>{{ formatArrivalTime(driver.created_at) }}</TableCell>
                <TableCell><Badge variant="outline">Menunggu persetujuan</Badge></TableCell>
                <TableCell>
                  <div class="flex justify-end gap-2">
                  <Button
                    size="sm"
                    :disabled="isRefreshing || processingQueueId !== null"
                    @click="approveDriver(driver)"
                  >
                    <LoaderCircle v-if="processingQueueId === driver.id" class="size-4 animate-spin" />
                    <Check v-else class="size-4" />
                    {{ processingQueueId === driver.id ? 'Memproses' : 'Setujui' }}
                  </Button>
                  <Button
                    variant="destructive"
                    size="sm"
                    :disabled="isRefreshing || processingQueueId !== null"
                    @click="requestCancel(driver)"
                  >
                    Cancel
                  </Button>
                  </div>
                </TableCell>
              </TableRow>
            </TableBody>
          </Table>
          <div
            v-if="pendingApprovals > 0 && !dashboardError"
            class="flex flex-wrap items-center justify-between gap-3 border-t pt-4"
          >
            <p class="text-sm text-muted-foreground">
              Menampilkan {{ (pageNumber - 1) * pageSize + 1 }}–{{ Math.min(pageNumber * pageSize, pendingApprovals) }}
              dari {{ pendingApprovals }} pengajuan
            </p>
            <div class="flex gap-2">
              <Button
                variant="outline"
                size="sm"
                :disabled="isRefreshing || pageNumber <= 1"
                @click="changePage(pageNumber - 1)"
              >
                Sebelumnya
              </Button>
              <Button
                variant="outline"
                size="sm"
                :disabled="isRefreshing || pageNumber >= pageCount"
                @click="changePage(pageNumber + 1)"
              >
                Berikutnya
              </Button>
            </div>
          </div>
        </CardContent>
      </Card>

      <Card>
        <CardHeader>
          <CardTitle class="flex items-center gap-2"><Dock class="size-4" /> Penugasan dock</CardTitle>
          <CardDescription>Status dock aktif di {{ plantLocation || 'plant akun' }}.</CardDescription>
        </CardHeader>
        <CardContent class="space-y-3">
          <p v-if="isLoading" class="py-4 text-center text-sm text-muted-foreground">
            <LoaderCircle class="mr-2 inline size-4 animate-spin" />
            Memuat data dock...
          </p>
          <p v-else-if="dashboardError" class="py-4 text-center text-sm text-muted-foreground">
            Data dock tidak dapat ditampilkan.
          </p>
          <p v-else-if="docks.length === 0" class="py-4 text-center text-sm text-muted-foreground">
            Belum ada dock aktif di plant ini.
          </p>
          <Card v-for="dock in docks" v-else :key="dock.id" size="sm" class="bg-muted/30">
            <CardContent class="flex items-center justify-between gap-3 p-3">
              <div class="min-w-0">
                <p class="truncate font-medium">{{ dock.name }}</p>
                <p class="truncate text-xs text-muted-foreground">
                  {{ dockQueueById.get(dock.id)?.queue_number ?? 'Tidak ada kendaraan' }}
                  <span v-if="dockQueueById.get(dock.id)"> · {{ dockQueueById.get(dock.id)?.license_plate }}</span>
                </p>
              </div>
              <Badge :variant="dockQueueById.has(dock.id) ? 'outline' : 'secondary'">
                {{ dockQueueById.has(dock.id) ? 'Digunakan' : 'Tersedia' }}
              </Badge>
            </CardContent>
          </Card>
        </CardContent>
      </Card>
    </section>

    <Dialog :open="isCancelDialogOpen" @update:open="handleCancelDialogOpenChange">
      <DialogContent>
        <DialogHeader>
          <DialogTitle>Batalkan pengajuan kendaraan?</DialogTitle>
          <DialogDescription>
            Pengajuan {{ queueToCancel?.queue_number }} untuk kendaraan {{ queueToCancel?.license_plate }}
            akan dipindahkan ke status dibatalkan.
          </DialogDescription>
        </DialogHeader>
        <p
          v-if="queueActionError"
          role="alert"
          class="rounded-lg border border-red-500/20 bg-red-500/10 px-3 py-2 text-sm text-red-700 dark:text-red-300"
        >
          {{ queueActionError }}
        </p>
        <DialogFooter>
          <Button
            variant="outline"
            :disabled="processingQueueId !== null"
            @click="handleCancelDialogOpenChange(false)"
          >
            Kembali
          </Button>
          <Button
            variant="destructive"
            :disabled="processingQueueId !== null"
            @click="cancelDriver"
          >
            <LoaderCircle v-if="processingQueueId === queueToCancel?.id" class="size-4 animate-spin" />
            {{ processingQueueId === queueToCancel?.id ? 'Membatalkan...' : 'Ya, batalkan' }}
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  </div>
</template>
