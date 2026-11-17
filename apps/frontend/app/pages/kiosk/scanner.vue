<script setup lang="ts">
import {
  ArrowRightLeft,
  BadgeCheck,
  CircleAlert,
  DoorOpen,
  LoaderCircle,
  LockKeyhole,
  LogOut,
  RefreshCw,
  ScanLine,
  ShieldCheck,
  Truck,
} from 'lucide-vue-next'
import { Badge } from '@/components/ui/badge'
import { Button } from '@/components/ui/button'
import {
  Card,
  CardContent,
  CardDescription,
  CardHeader,
  CardTitle,
} from '@/components/ui/card'
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from '@/components/ui/dialog'
import { Label } from '@/components/ui/label'
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from '@/components/ui/select'
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from '@/components/ui/table'

definePageMeta({ layout: 'default' })

const plantOptions = ['Jatake 1', 'Jatake 2', 'Jatake 3', 'Jatake 6'] as const
const configStorageKey = 'kiosk_gate_config'
const historyStorageKey = 'kiosk_scan_history'
const changeGatePin = '123456'

type PlantLocation = typeof plantOptions[number]
type GateNode = {
  id: string
  name: string
  plant_location: string
}
type KioskConfig = {
  plant_location: PlantLocation
  gate_node_id: string
}
type QueueRecord = {
  queue_number: string
  driver_name: string
  driver_phone: string
  license_plate: string
  cargo_type: string
  plant_location: string
  initial_plant_location: string | null
  status: string
}
type ScanBadge = 'CHECK-IN' | 'ALIH PLANT' | 'EXIT TRANSFER' | 'CHECK-OUT' | 'DITOLAK'
type ScanHistoryEntry = {
  scanned_at: string
  queue_number: string
  license_plate: string
  badge: ScanBadge
}
type FeedbackKind = 'success' | 'warning' | 'info' | 'error'
type ScanFeedback = {
  kind: FeedbackKind
  title: string
  message: string
}
type ScanRpcResult = {
  outcome: string
  queue_status: string | null
  source_plant: string | null
  target_plant: string | null
}

const supabase = useSupabaseClient()
const route = useRoute()
const scanInput = ref<HTMLInputElement | null>(null)
const activeConfig = ref<KioskConfig | null>(null)
const gateNodes = ref<GateNode[]>([])
const setupPlant = ref<PlantLocation>('Jatake 1')
const selectedGateNodeId = ref('')
const scanValue = ref('')
const scanHistory = ref<ScanHistoryEntry[]>([])
const feedback = ref<ScanFeedback | null>(null)
const scanDetails = ref<QueueRecord | null>(null)
const scannedQueueNumber = ref('')
const scanBadge = ref<ScanBadge>('DITOLAK')
const setupError = ref('')
const gateLoadError = ref('')
const pinError = ref('')
const pinValue = ref('')
const isLoadingGates = ref(true)
const isProcessingScan = ref(false)
const isPinDialogOpen = ref(false)
const isScanResultDialogOpen = ref(false)

const availableGates = computed(() => gateNodes.value.filter(
  gate => gate.plant_location === setupPlant.value,
))
const activeGate = computed(() => (
  gateNodes.value.find(gate => gate.id === activeConfig.value?.gate_node_id) ?? null
))
const feedbackClasses: Record<FeedbackKind, string> = {
  success: 'border-emerald-200 bg-emerald-50 text-emerald-950',
  warning: 'border-amber-200 bg-amber-50 text-amber-950',
  info: 'border-blue-200 bg-blue-50 text-blue-950',
  error: 'border-rose-200 bg-rose-50 text-rose-950',
}
const historyBadgeClasses: Record<ScanBadge, string> = {
  'CHECK-IN': 'border-emerald-200 bg-emerald-50 text-emerald-800',
  'ALIH PLANT': 'border-amber-200 bg-amber-50 text-amber-800',
  'EXIT TRANSFER': 'border-blue-200 bg-blue-50 text-blue-800',
  'CHECK-OUT': 'border-blue-200 bg-blue-50 text-blue-800',
  DITOLAK: 'border-rose-200 bg-rose-50 text-rose-800',
}

function isPlantLocation(value: unknown): value is PlantLocation {
  return typeof value === 'string' && plantOptions.includes(value as PlantLocation)
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === 'object' && value !== null
}

function getErrorMessage(error: unknown) {
  if (error instanceof Error) return error.message
  if (isRecord(error) && typeof error.message === 'string') return error.message
  return 'Terjadi kesalahan. Silakan coba kembali.'
}

function getQueryValue(value: unknown) {
  if (Array.isArray(value)) return typeof value[0] === 'string' ? value[0] : ''
  return typeof value === 'string' ? value : ''
}

function readStoredConfig() {
  const rawConfig = localStorage.getItem(configStorageKey)
  if (!rawConfig) return null

  try {
    const parsed: unknown = JSON.parse(rawConfig)
    if (
      isRecord(parsed)
      && isPlantLocation(parsed.plant_location)
      && typeof parsed.gate_node_id === 'string'
    ) {
      return {
        plant_location: parsed.plant_location,
        gate_node_id: parsed.gate_node_id,
      } satisfies KioskConfig
    }
  } catch {
    localStorage.removeItem(configStorageKey)
  }

  return null
}

function saveConfig(config: KioskConfig) {
  activeConfig.value = config
  localStorage.setItem(configStorageKey, JSON.stringify(config))
  feedback.value = null
  setupError.value = ''
  void focusScanInput()
}

function restoreScanHistory() {
  const rawHistory = sessionStorage.getItem(historyStorageKey)
  if (!rawHistory) return

  try {
    const parsed: unknown = JSON.parse(rawHistory)
    if (!Array.isArray(parsed)) return

    scanHistory.value = parsed
      .filter((entry): entry is ScanHistoryEntry => (
        isRecord(entry)
        && typeof entry.scanned_at === 'string'
        && typeof entry.queue_number === 'string'
        && typeof entry.license_plate === 'string'
        && ['CHECK-IN', 'ALIH PLANT', 'EXIT TRANSFER', 'CHECK-OUT', 'DITOLAK'].includes(
          String(entry.badge),
        )
      ))
      .slice(0, 5)
  } catch {
    sessionStorage.removeItem(historyStorageKey)
  }
}

async function loadGateNodes() {
  isLoadingGates.value = true
  gateLoadError.value = ''
  setupError.value = ''

  try {
    const { data, error } = await supabase
      .from('map_nodes')
      .select('id, name, plant_location')
      .eq('node_type', 'gate')
      .eq('is_active', true)
      .order('plant_location', { ascending: true })
      .order('name', { ascending: true })

    if (error) throw error
    gateNodes.value = (data ?? []) as GateNode[]

    const queryPlant = getQueryValue(route.query.plant)
    const queryNodeId = getQueryValue(route.query.node_id)
    const storedConfig = readStoredConfig()
    const queryWasProvided = Boolean(queryPlant || queryNodeId)

    if (queryWasProvided) {
      const queryGate = gateNodes.value.find(gate => (
        gate.id === queryNodeId && gate.plant_location === queryPlant
      ))

      if (isPlantLocation(queryPlant) && queryGate) {
        setupPlant.value = queryPlant
        selectedGateNodeId.value = queryGate.id
        saveConfig({ plant_location: queryPlant, gate_node_id: queryGate.id })
        return
      }
    }

    if (storedConfig) {
      const storedGate = gateNodes.value.find(gate => (
        gate.id === storedConfig.gate_node_id
        && gate.plant_location === storedConfig.plant_location
      ))

      if (storedGate) {
        activeConfig.value = storedConfig
        setupPlant.value = storedConfig.plant_location
        selectedGateNodeId.value = storedGate.id
        return
      }
      localStorage.removeItem(configStorageKey)
    }

    if (queryWasProvided) {
      setupError.value = 'Parameter plant atau node_id tidak valid. Pilih pos gate yang aktif.'
    }

    if (isPlantLocation(queryPlant)) setupPlant.value = queryPlant
    selectedGateNodeId.value = ''
  } catch (error) {
    console.error('Unable to load active gate nodes for the kiosk scanner', error)
    gateLoadError.value = getErrorMessage(error)
  } finally {
    isLoadingGates.value = false
    if (activeConfig.value) await focusScanInput()
  }
}

function saveGateSetup() {
  setupError.value = ''

  if (!isPlantLocation(setupPlant.value)) {
    setupError.value = 'Pilih plant lokasi pos terlebih dahulu.'
    return
  }

  const gate = availableGates.value.find(node => node.id === selectedGateNodeId.value)
  if (!gate) {
    setupError.value = 'Pilih node gerbang aktif untuk plant ini.'
    return
  }

  saveConfig({ plant_location: setupPlant.value, gate_node_id: gate.id })
}

async function focusScanInput() {
  await nextTick()
  scanInput.value?.focus()
}

function recordScan(queueNumber: string, licensePlate: string, badge: ScanBadge) {
  const entry: ScanHistoryEntry = {
    scanned_at: new Date().toISOString(),
    queue_number: queueNumber,
    license_plate: licensePlate,
    badge,
  }
  scanHistory.value = [entry, ...scanHistory.value].slice(0, 5)
  sessionStorage.setItem(historyStorageKey, JSON.stringify(scanHistory.value))
}

function showFeedback(kind: FeedbackKind, title: string, message: string) {
  feedback.value = { kind, title, message }
  isScanResultDialogOpen.value = true
}

function rejectionMessage(status: string) {
  if (status === 'pending') return 'Antrean belum disetujui Admin Logistik'
  if (['waiting_in_yard', 'called_to_dock', 'unloading'].includes(status)) {
    return 'Akses keluar ditolak: Proses bongkar muat belum diselesaikan Operator Yard'
  }
  if (status === 'checked_out' || status === 'cancelled') {
    return 'Tiket QR sudah tidak berlaku / sudah Check-Out'
  }
  return 'Status tiket berubah. Periksa kembali antrean bersama Admin Logistik.'
}

function statusLabel(status: string) {
  const labels: Record<string, string> = {
    pending: 'Menunggu persetujuan',
    approved: 'Disetujui',
    waiting_in_yard: 'Menunggu di yard',
    called_to_dock: 'Dipanggil ke dock',
    unloading: 'Bongkar muat',
    completed: 'Selesai bongkar',
    checked_out: 'Sudah keluar',
    cancelled: 'Dibatalkan',
  }
  return labels[status] ?? status
}

function getRpcResult(value: unknown): ScanRpcResult | null {
  const row = Array.isArray(value) ? value[0] : value
  if (
    !isRecord(row)
    || typeof row.outcome !== 'string'
    || !(typeof row.queue_status === 'string' || row.queue_status === null)
    || !(typeof row.source_plant === 'string' || row.source_plant === null)
    || !(typeof row.target_plant === 'string' || row.target_plant === null)
  ) {
    return null
  }

  return {
    outcome: row.outcome,
    queue_status: row.queue_status,
    source_plant: row.source_plant,
    target_plant: row.target_plant,
  }
}

async function processScan() {
  if (isProcessingScan.value) return

  const queueNumber = scanValue.value.trim()
  if (!queueNumber) {
    await focusScanInput()
    return
  }

  isProcessingScan.value = true
  feedback.value = null
  scanDetails.value = null
  scannedQueueNumber.value = queueNumber
  scanBadge.value = 'DITOLAK'
  let scannedPlate = '—'
  let scanWasRecorded = false
  const recordOutcome = (badge: ScanBadge) => {
    if (scanWasRecorded) return
    scanWasRecorded = true
    scanBadge.value = badge
    recordScan(queueNumber, scannedPlate, badge)
  }

  try {
    if (!activeConfig.value || !activeGate.value) {
      throw new Error('Pos gate belum dikonfigurasi atau sudah tidak aktif.')
    }

    const { data, error } = await supabase
      .from('logistics_queues')
      .select('queue_number, driver_name, driver_phone, license_plate, cargo_type, plant_location, initial_plant_location, status')
      .eq('queue_number', queueNumber)
      .maybeSingle()

    if (error) throw error

    const queue = data as QueueRecord | null
    if (!queue) {
      showFeedback('error', 'QR tidak ditemukan', `Nomor antrean ${queueNumber} tidak terdaftar.`)
      recordOutcome('DITOLAK')
      return
    }
    scannedPlate = queue.license_plate
    scanDetails.value = queue

    if (queue.status === 'pending') {
      showFeedback('error', 'Antrean belum disetujui', rejectionMessage(queue.status))
      recordOutcome('DITOLAK')
      return
    }

    if (['waiting_in_yard', 'called_to_dock', 'unloading'].includes(queue.status)) {
      showFeedback('error', 'Akses keluar ditolak', rejectionMessage(queue.status))
      recordOutcome('DITOLAK')
      return
    }

    if (queue.status === 'checked_out' || queue.status === 'cancelled') {
      showFeedback('error', 'Tiket tidak berlaku', rejectionMessage(queue.status))
      recordOutcome('DITOLAK')
      return
    }

    if (queue.status !== 'approved' && queue.status !== 'completed') {
      showFeedback('error', 'Scan ditolak', rejectionMessage(queue.status))
      recordOutcome('DITOLAK')
      return
    }

    const action = queue.status === 'approved' ? 'check_in' : 'check_out'
    const { data: rpcData, error: rpcError } = await supabase.rpc('kiosk_process_queue_scan', {
      p_queue_number: queue.queue_number,
      p_plant_location: activeConfig.value.plant_location,
      p_gate_node_id: activeConfig.value.gate_node_id,
      p_action: action,
    })

    if (rpcError) throw rpcError

    const result = getRpcResult(rpcData)
    if (!result) throw new Error('Respons pemrosesan scan dari server tidak valid.')

    if (result.outcome === 'check_in') {
      scanDetails.value = {
        ...queue,
        plant_location: activeConfig.value.plant_location,
        status: 'waiting_in_yard',
      }
      showFeedback(
        'success',
        'Check-In Berhasil',
        `Kendaraan masuk ke ${activeConfig.value.plant_location} melalui ${activeGate.value.name}.`,
      )
      recordOutcome('CHECK-IN')
      return
    }

    if (result.outcome === 'rerouted') {
      const sourcePlant = result.source_plant ?? queue.plant_location
      scanDetails.value = {
        ...queue,
        initial_plant_location: queue.initial_plant_location ?? sourcePlant,
        plant_location: activeConfig.value.plant_location,
        status: 'waiting_in_yard',
      }
      showFeedback(
        'warning',
        'Check-In Berhasil (Alih Plant)',
        `Tiket dari ${sourcePlant} dialihkan otomatis masuk ke ${activeConfig.value.plant_location} melalui ${activeGate.value.name}`,
      )
      recordOutcome('ALIH PLANT')
      return
    }

    if (result.outcome === 'exit_transfer') {
      const targetPlant = result.target_plant ?? queue.plant_location
      showFeedback(
        'info',
        'Izin Keluar Transfer Plant',
        `Silakan menuju gerbang ${targetPlant}`,
      )
      recordOutcome('EXIT TRANSFER')
      return
    }

    if (result.outcome === 'checked_out') {
      scanDetails.value = { ...queue, status: 'checked_out' }
      showFeedback(
        'info',
        'Check-Out Berhasil',
        'Kendaraan telah selesai dan keluar dari area pabrik',
      )
      recordOutcome('CHECK-OUT')
      return
    }

    if (result.outcome === 'not_found') {
      showFeedback('error', 'QR tidak ditemukan', `Nomor antrean ${queueNumber} tidak terdaftar.`)
      recordOutcome('DITOLAK')
      return
    }

    const status = result.queue_status ?? queue.status
    scanDetails.value = { ...queue, status }
    showFeedback('error', 'Scan ditolak', rejectionMessage(status))
    recordOutcome('DITOLAK')
  } catch (error) {
    console.error('Unable to process kiosk queue scan', error)
    recordOutcome('DITOLAK')
    showFeedback('error', 'Scan gagal diproses', getErrorMessage(error))
  } finally {
    scanValue.value = ''
    isProcessingScan.value = false
    if (!isScanResultDialogOpen.value) await focusScanInput()
  }
}

function openChangeGateDialog() {
  pinValue.value = ''
  pinError.value = ''
  isPinDialogOpen.value = true
}

function confirmChangeGate() {
  if (pinValue.value !== changeGatePin) {
    pinError.value = 'PIN tidak sesuai. Pos gate tidak diubah.'
    return
  }

  localStorage.removeItem(configStorageKey)
  activeConfig.value = null
  feedback.value = null
  pinValue.value = ''
  pinError.value = ''
  isPinDialogOpen.value = false
}

function formatScanTime(value: string) {
  return new Date(value).toLocaleTimeString('id-ID', {
    hour: '2-digit',
    minute: '2-digit',
    second: '2-digit',
    timeZone: 'Asia/Jakarta',
  })
}

watch(isScanResultDialogOpen, (isOpen) => {
  if (!isOpen && activeConfig.value) void focusScanInput()
})

onMounted(() => {
  restoreScanHistory()
  void loadGateNodes()
})
</script>

<template>
  <main class="min-h-screen bg-zinc-50 px-3 py-4 text-zinc-950 sm:px-6 sm:py-6 lg:px-8">
    <div class="mx-auto flex w-full max-w-7xl flex-col gap-5 sm:gap-6">
      <header class="relative isolate min-h-[270px] overflow-hidden rounded-3xl border border-zinc-800 bg-zinc-900 shadow-2xl shadow-black/30 sm:min-h-[300px]">
        <img
          src="/img/bgformlogistic.webp"
          alt=""
          class="absolute inset-0 -z-20 size-full object-cover object-center opacity-55"
        />
        <div class="absolute inset-0 -z-10 bg-gradient-to-r from-zinc-950 via-zinc-950/85 to-zinc-950/45" />
        <div class="absolute inset-0 -z-10 bg-gradient-to-t from-zinc-950/80 via-transparent to-zinc-950/30" />

        <div class="flex min-h-[270px] flex-col justify-between gap-10 p-5 sm:min-h-[300px] sm:p-8 lg:p-10">
          <div class="flex flex-col gap-4 sm:flex-row sm:items-start sm:justify-between">
            <div class="flex items-center gap-3">
              <img
                src="/img/entrivaputih.png"
                alt="Entriva"
                class="h-8 w-auto max-w-[150px] object-contain object-left sm:h-9"
              />
              <div>
                <h1 class="mt-1 text-xl font-medium text-white">Entriva</h1>
              </div>
            </div>

            <div class="flex flex-col gap-2 sm:items-end">
              <Badge
                v-if="activeConfig && activeGate"
                class="w-fit max-w-full gap-1.5 border bg-zinc-950/65 px-3 py-1.5 text-left text-xs leading-5 text-white backdrop-blur-md"
              >
                <ShieldCheck class="size-3.5 shrink-0" />
                <span>POS AKTIF: {{ activeConfig.plant_location }} — {{ activeGate.name }}</span>
              </Badge>
              <Badge v-else variant="outline" class="w-fit border-zinc-500/50 bg-zinc-950/50 px-3 py-1.5 text-xs text-zinc-200 backdrop-blur-md">
                POS BELUM DIATUR
              </Badge>
              <Button
                v-if="activeConfig"
                variant="outline"
                size="sm"
                class="w-fit border-white/20 bg-zinc-950/45 text-zinc-100 backdrop-blur-md hover:bg-white/10 hover:text-white"
                @click="openChangeGateDialog"
              >
                <LockKeyhole class="size-3.5" />
                Ganti Pos Gate
              </Button>
            </div>
          </div>

          <div class="max-w-2xl">
            <h1 class="text-3xl font-semibold tracking-tight text-white sm:text-4xl lg:text-5xl">
              Gate <span class="text-amber-300">Scanner</span>
            </h1>
          </div>
        </div>
      </header>

      <div
        v-if="gateLoadError"
        role="alert"
        class="rounded-2xl border border-rose-200 bg-rose-50 p-4 text-sm text-rose-900"
      >
        Node gerbang gagal dimuat: {{ gateLoadError }}
      </div>

      <section v-if="!activeConfig" class="grid gap-4 lg:grid-cols-[minmax(0,1.15fr)_minmax(300px,0.85fr)] lg:gap-6">
        <Card class="rounded-2xl border-zinc-200 bg-white text-zinc-950 shadow-xl shadow-zinc-900/5">
          <CardHeader class="gap-3 px-5 pt-6 sm:px-7">
            <div class="flex size-11 items-center justify-center rounded-xl border border-amber-200 bg-amber-50 text-amber-700">
              <DoorOpen class="size-5" />
            </div>
            <CardTitle class="text-xl font-semibold text-zinc-950 sm:text-2xl">Atur Identitas Pos Gate</CardTitle>
            <CardDescription class="text-zinc-600">
              Pilih plant dan node gerbang aktif untuk perangkat kiosk ini. Pengaturan disimpan pada perangkat.
            </CardDescription>
          </CardHeader>
          <CardContent class="px-5 pb-6 sm:px-7">
            <form class="space-y-5" @submit.prevent="saveGateSetup">
              <div class="space-y-2">
                <Label for="setup-plant" class="text-zinc-700">Plant lokasi pos</Label>
                <Select
                  v-model="setupPlant"
                  @update:model-value="selectedGateNodeId = ''"
                >
                  <SelectTrigger id="setup-plant" class="w-full border-zinc-300 bg-white text-zinc-900">
                    <SelectValue placeholder="Pilih plant" />
                  </SelectTrigger>
                  <SelectContent>
                    <SelectItem v-for="plant in plantOptions" :key="plant" :value="plant">
                      {{ plant }}
                    </SelectItem>
                  </SelectContent>
                </Select>
              </div>

              <div class="space-y-2">
                <Label for="setup-gate" class="text-zinc-700">Node gerbang aktif</Label>
                <Select v-model="selectedGateNodeId" :disabled="isLoadingGates || availableGates.length === 0">
                  <SelectTrigger id="setup-gate" class="w-full border-zinc-300 bg-white text-zinc-900">
                    <SelectValue :placeholder="isLoadingGates ? 'Memuat gerbang...' : 'Pilih node gerbang'" />
                  </SelectTrigger>
                  <SelectContent>
                    <SelectItem v-for="gate in availableGates" :key="gate.id" :value="gate.id">
                      {{ gate.name }}
                    </SelectItem>
                  </SelectContent>
                </Select>
                <p v-if="!isLoadingGates && availableGates.length === 0" class="text-xs text-amber-700">
                  Tidak ada node gerbang aktif untuk {{ setupPlant }}.
                </p>
              </div>

              <p v-if="setupError" role="alert" class="text-sm text-rose-700">
                {{ setupError }}
              </p>

              <Button
                type="submit"
                class="h-11 w-full rounded-xl bg-amber-300 font-semibold text-zinc-950 shadow-lg shadow-amber-950/20 hover:bg-amber-200"
                :disabled="isLoadingGates || Boolean(gateLoadError)"
              >
                Simpan Identitas Pos
              </Button>
            </form>
          </CardContent>
        </Card>

        <Card class="rounded-2xl border-zinc-200 bg-white text-zinc-950 shadow-xl shadow-zinc-900/5">
          <CardHeader class="px-5 pt-6 sm:px-6">
            <div class="mb-1 flex size-10 items-center justify-center rounded-xl bg-zinc-100 text-amber-700">
              <Truck class="size-5" />
            </div>
            <CardTitle class="text-lg text-zinc-950">
              Satu QR, seluruh perjalanan
            </CardTitle>
            <CardDescription class="leading-6 text-zinc-600">
              Barcode antrean yang sama digunakan untuk check-in, izin keluar transfer plant, dan check-out setelah proses bongkar selesai.
            </CardDescription>
          </CardHeader>
          <CardContent class="px-5 pb-6 sm:px-6">
            <div class="space-y-0 text-sm text-zinc-700">
              <div class="flex gap-3 pb-4">
                <div class="flex flex-col items-center">
                  <Badge variant="outline" class="size-8 shrink-0 rounded-full border-emerald-200 bg-emerald-50 p-0 text-xs font-bold text-emerald-700">01</Badge>
                  <span class="mt-1 h-full w-px bg-zinc-200" />
                </div>
                <div class="pb-2">
                  <p class="font-medium text-zinc-900">Check-in di gerbang</p>
                  <p class="mt-1 text-xs leading-5 text-zinc-500">Tiket disetujui dan kendaraan masuk ke area plant.</p>
                </div>
              </div>
              <div class="flex gap-3 pb-4">
                <div class="flex flex-col items-center">
                  <Badge variant="outline" class="size-8 shrink-0 rounded-full border-amber-200 bg-amber-50 p-0 text-xs font-bold text-amber-700">02</Badge>
                  <span class="mt-1 h-full w-px bg-zinc-200" />
                </div>
                <div class="pb-2">
                  <p class="font-medium text-zinc-900">Transfer antar-plant</p>
                  <p class="mt-1 text-xs leading-5 text-zinc-500">Gunakan barcode yang sama untuk izin keluar menuju plant tujuan.</p>
                </div>
              </div>
              <div class="flex gap-3">
                <Badge variant="outline" class="size-8 shrink-0 rounded-full border-blue-200 bg-blue-50 p-0 text-xs font-bold text-blue-700">03</Badge>
                <div>
                  <p class="font-medium text-zinc-900">Check-out setelah bongkar</p>
                  <p class="mt-1 text-xs leading-5 text-zinc-500">Kendaraan keluar setelah status bongkar dinyatakan selesai.</p>
                </div>
              </div>
            </div>
          </CardContent>
        </Card>
      </section>

      <template v-else>
        <section class="grid gap-4 lg:grid-cols-[minmax(0,1.45fr)_minmax(300px,0.75fr)] lg:gap-6">
          <Card class="rounded-2xl border-zinc-200 bg-white text-zinc-950 shadow-xl shadow-zinc-900/5">
            <CardHeader class="gap-3 px-5 pt-6 sm:px-7 sm:pt-7">
              <div class="flex flex-wrap items-center justify-between gap-3">
                <div class="flex items-center gap-3">
                  <div class="flex size-8 items-center justify-center rounded-lg bg-zinc-100 text-zinc-600">
                    <ScanLine class="size-5" />
                  </div>
                  <div>
                    <CardTitle class="mt-1 text-lg text-zinc-950 sm:text-xl">Pindai Barcode</CardTitle>
                  </div>
                </div>
              </div>
              <CardDescription class="max-w-2xl leading-6 text-zinc-600">
                Arahkan scanner ke barcode tiket logistik. Handheld scanner akan otomatis mengirim nomor antrean saat menekan Enter.
              </CardDescription>
            </CardHeader>
            <CardContent class="px-5 pb-6 sm:px-7 sm:pb-7">
              <form class="space-y-3" @submit.prevent="processScan">
                <div class="space-y-2">
                  <Label for="queue-number" class="text-xs font-medium text-zinc-600">NOMOR ANTREAN / QR CODE</Label>
                  <input
                    id="queue-number"
                    ref="scanInput"
                    v-model="scanValue"
                    type="text"
                    autocomplete="off"
                    autocapitalize="characters"
                    spellcheck="false"
                    autofocus
                    placeholder="Pindai atau ketik nomor barcode"
                    class="h-16 w-full rounded-xl border border-zinc-300 bg-white px-4 font-mono text-lg tracking-wide text-zinc-950 shadow-inner shadow-zinc-900/5 outline-none transition placeholder:text-sm placeholder:tracking-normal placeholder:text-zinc-400 focus-visible:border-amber-400 focus-visible:ring-4 focus-visible:ring-amber-300/20 sm:text-xl"
                    :disabled="isProcessingScan"
                    @keydown.enter.prevent="processScan"
                  />
                </div>
                <div class="flex flex-col gap-3 pt-1 sm:flex-row sm:items-center sm:justify-between">
                  <Button
                    type="submit"
                    class="h-11 shrink-0 rounded-xl bg-amber-300 px-5 font-semibold text-zinc-950 shadow-md shadow-amber-950/20 hover:bg-amber-200 sm:min-w-40"
                    :disabled="isProcessingScan || !scanValue.trim()"
                  >
                    <LoaderCircle v-if="isProcessingScan" class="size-4 animate-spin" />
                    <ScanLine v-else class="size-4" />
                    {{ isProcessingScan ? 'Memproses...' : 'Proses Scan' }}
                  </Button>
                </div>
              </form>
            </CardContent>
          </Card>

          <Card class="rounded-2xl border-zinc-200 bg-white text-zinc-950 shadow-xl shadow-zinc-900/5">
            <CardHeader class="px-5 pt-6 sm:px-6">
              <div class="flex items-center justify-between gap-3">
                <div class="flex size-10 items-center justify-center rounded-xl bg-zinc-100 text-amber-700">
                  <ShieldCheck class="size-5" />
                </div>
                <Badge variant="secondary">
                  POS GATE
                </Badge>
              </div>
              <CardTitle class="text-lg text-zinc-950">Alur validasi tiket</CardTitle>
              <CardDescription class="text-zinc-600">
                Status antrean menentukan akses kendaraan.
              </CardDescription>
            </CardHeader>
            <CardContent class="space-y-2 px-5 pb-6 sm:px-6">
              <div class="flex items-center gap-3 rounded-xl border border-zinc-200 bg-zinc-50 p-3">
                <span class="flex size-8 shrink-0 items-center justify-center rounded-lg bg-emerald-500/10 text-emerald-300">
                  <BadgeCheck class="size-4" />
                </span>
                <span class="min-w-0 flex-1 text-sm text-zinc-700">Tiket disetujui</span>
                <Badge class="border-emerald-200 bg-emerald-50 text-[10px] text-emerald-800">MASUK</Badge>
              </div>
              <div class="flex items-center gap-3 rounded-xl border border-zinc-200 bg-zinc-50 p-3">
                <span class="flex size-8 shrink-0 items-center justify-center rounded-lg bg-amber-500/10 text-amber-300">
                  <ArrowRightLeft class="size-4" />
                </span>
                <span class="min-w-0 flex-1 text-sm text-zinc-700">Alih plant otomatis</span>
                <Badge class="border-amber-200 bg-amber-50 text-[10px] text-amber-800">TRANSFER</Badge>
              </div>
              <div class="flex items-center gap-3 rounded-xl border border-zinc-200 bg-zinc-50 p-3">
                <span class="flex size-8 shrink-0 items-center justify-center rounded-lg bg-blue-500/10 text-blue-300">
                  <LogOut class="size-4" />
                </span>
                <span class="min-w-0 flex-1 text-sm text-zinc-700">Bongkar selesai</span>
                <Badge class="border-blue-200 bg-blue-50 text-[10px] text-blue-800">KELUAR</Badge>
              </div>
              <div class="mt-4 rounded-xl border border-zinc-200 bg-gradient-to-br from-zinc-100 to-white p-4">
                <p class="text-[10px] font-semibold tracking-[0.16em] text-zinc-500">LOKASI SCANNER</p>
                <p class="mt-2 font-semibold text-zinc-950">{{ activeConfig?.plant_location }}</p>
                <p class="mt-1 text-sm text-zinc-600">{{ activeGate?.name }}</p>
              </div>
            </CardContent>
          </Card>
        </section>

        <Card class="rounded-2xl border-zinc-200 bg-white text-zinc-950 shadow-xl shadow-zinc-900/5">
          <CardHeader class="flex-row items-center justify-between px-5 pt-5 sm:px-6">
            <div>
              <div class="flex items-center gap-2">
                <div class="flex size-8 items-center justify-center rounded-lg bg-zinc-100 text-zinc-600">
                  <RefreshCw class="size-4" />
                </div>
                <CardTitle class="text-base text-zinc-950">Riwayat scan</CardTitle>
              </div>
              <CardDescription class="mt-1 text-zinc-600">
                Lima aktivitas terakhir pada sesi perangkat ini.
              </CardDescription>
            </div>
            <Badge variant="outline" class="border-zinc-200 text-[10px] text-zinc-600">
              {{ scanHistory.length }} / 5
            </Badge>
          </CardHeader>
          <CardContent class="px-5 pb-5 sm:px-6 sm:pb-6">
            <div v-if="scanHistory.length === 0" class="rounded-xl border border-dashed border-zinc-300 bg-zinc-50 px-4 py-10 text-center text-sm text-zinc-500">
              Belum ada scan pada sesi ini.
            </div>
            <div v-else class="overflow-x-auto">
              <Table class="min-w-[620px]">
                <TableHeader>
                  <TableRow class="border-zinc-200 hover:bg-transparent">
                    <TableHead class="h-10 text-[10px] font-semibold tracking-[0.14em] text-zinc-500">WAKTU</TableHead>
                    <TableHead class="h-10 text-[10px] font-semibold tracking-[0.14em] text-zinc-500">PLAT NOMOR</TableHead>
                    <TableHead class="h-10 text-[10px] font-semibold tracking-[0.14em] text-zinc-500">NOMOR ANTREAN</TableHead>
                    <TableHead class="h-10 text-[10px] font-semibold tracking-[0.14em] text-zinc-500">STATUS</TableHead>
                  </TableRow>
                </TableHeader>
                <TableBody>
                  <TableRow
                    v-for="entry in scanHistory"
                    :key="`${entry.scanned_at}-${entry.queue_number}`"
                    class="border-zinc-200 hover:bg-zinc-50"
                  >
                    <TableCell class="whitespace-nowrap font-mono text-xs text-zinc-500">
                      {{ formatScanTime(entry.scanned_at) }} WIB
                    </TableCell>
                    <TableCell class="whitespace-nowrap font-mono text-sm font-semibold text-zinc-800">
                      {{ entry.license_plate }}
                    </TableCell>
                    <TableCell class="whitespace-nowrap font-mono text-xs text-zinc-500">
                      {{ entry.queue_number }}
                    </TableCell>
                    <TableCell>
                      <Badge variant="outline" class="whitespace-nowrap" :class="historyBadgeClasses[entry.badge]">
                        {{ entry.badge }}
                      </Badge>
                    </TableCell>
                  </TableRow>
                </TableBody>
              </Table>
            </div>
          </CardContent>
        </Card>
      </template>
    </div>

    <Dialog v-model:open="isScanResultDialogOpen">
      <DialogContent class="max-h-[90vh] overflow-y-auto border-zinc-200 bg-white p-0 text-zinc-950 shadow-2xl sm:max-w-xl">
        <div
          v-if="feedback"
          class="border-b px-5 py-5 sm:px-6"
          :class="feedbackClasses[feedback.kind]"
        >
          <DialogHeader class="space-y-3 text-left">
            <div class="flex items-start gap-3">
              <div class="mt-0.5 flex size-10 shrink-0 items-center justify-center rounded-xl bg-white/80 shadow-sm">
                <CircleAlert v-if="feedback.kind === 'error'" class="size-5 text-rose-600" />
                <BadgeCheck v-else-if="feedback.kind === 'success'" class="size-5 text-emerald-600" />
                <ArrowRightLeft v-else-if="feedback.kind === 'warning'" class="size-5 text-amber-600" />
                <LogOut v-else class="size-5 text-blue-600" />
              </div>
              <div class="min-w-0 flex-1">
                <div class="flex flex-wrap items-center justify-between gap-2">
                  <DialogTitle class="text-lg font-semibold text-current sm:text-xl">
                    {{ feedback.title }}
                  </DialogTitle>
                  <Badge variant="outline" class="whitespace-nowrap" :class="historyBadgeClasses[scanBadge]">
                    {{ scanBadge }}
                  </Badge>
                </div>
                <DialogDescription class="mt-1 text-sm leading-6 text-current/80">
                  {{ feedback.message }}
                </DialogDescription>
              </div>
            </div>
          </DialogHeader>
        </div>

        <div class="space-y-5 px-5 py-5 sm:px-6">
          <template v-if="scanDetails">
            <div class="flex items-center gap-3 rounded-xl bg-zinc-950 px-4 py-3.5 text-white">
              <div class="flex size-10 shrink-0 items-center justify-center rounded-lg bg-white/10 text-amber-300">
                <Truck class="size-5" />
              </div>
              <div class="min-w-0 flex-1">
                <p class="text-[10px] font-semibold tracking-[0.16em] text-zinc-400">PLAT NOMOR</p>
                <p class="mt-1 truncate font-mono text-lg font-bold tracking-wide">
                  {{ scanDetails.license_plate }}
                </p>
              </div>
              <Badge variant="outline" class="hidden border-white/20 text-xs text-zinc-200 sm:inline-flex">
                {{ statusLabel(scanDetails.status) }}
              </Badge>
            </div>

            <section>
              <h3 class="mb-3 text-sm font-semibold text-zinc-900">Informasi supir & kendaraan</h3>
              <div class="grid gap-3 sm:grid-cols-2">
                <div class="rounded-xl border border-zinc-200 bg-zinc-50 p-3.5">
                  <p class="text-[10px] font-semibold tracking-[0.14em] text-zinc-500">NAMA SUPIR</p>
                  <p class="mt-1.5 break-words text-sm font-medium text-zinc-900">{{ scanDetails.driver_name }}</p>
                </div>
                <div class="rounded-xl border border-zinc-200 bg-zinc-50 p-3.5">
                  <p class="text-[10px] font-semibold tracking-[0.14em] text-zinc-500">NOMOR TELEPON</p>
                  <p class="mt-1.5 break-words font-mono text-sm text-zinc-800">{{ scanDetails.driver_phone }}</p>
                </div>
                <div class="rounded-xl border border-zinc-200 bg-zinc-50 p-3.5">
                  <p class="text-[10px] font-semibold tracking-[0.14em] text-zinc-500">NOMOR ANTREAN</p>
                  <p class="mt-1.5 break-all font-mono text-sm font-medium text-zinc-900">{{ scanDetails.queue_number }}</p>
                </div>
                <div class="rounded-xl border border-zinc-200 bg-zinc-50 p-3.5">
                  <p class="text-[10px] font-semibold tracking-[0.14em] text-zinc-500">JENIS MUATAN</p>
                  <p class="mt-1.5 break-words text-sm text-zinc-800">{{ scanDetails.cargo_type }}</p>
                </div>
                <div class="rounded-xl border border-zinc-200 bg-zinc-50 p-3.5">
                  <p class="text-[10px] font-semibold tracking-[0.14em] text-zinc-500">PLANT TIKET</p>
                  <p class="mt-1.5 text-sm font-medium text-zinc-900">{{ scanDetails.plant_location }}</p>
                </div>
                <div class="rounded-xl border border-zinc-200 bg-zinc-50 p-3.5">
                  <p class="text-[10px] font-semibold tracking-[0.14em] text-zinc-500">STATUS ANTREAN</p>
                  <p class="mt-1.5 text-sm font-medium text-zinc-900">{{ statusLabel(scanDetails.status) }}</p>
                </div>
              </div>
            </section>

            <div class="flex items-start gap-3 rounded-xl border border-zinc-200 bg-white p-3.5">
              <ShieldCheck class="mt-0.5 size-4 shrink-0 text-amber-600" />
              <div>
                <p class="text-xs font-semibold text-zinc-900">Pos pemindaian</p>
                <p class="mt-1 text-sm text-zinc-600">
                  {{ activeConfig?.plant_location }}<span v-if="activeGate"> · {{ activeGate.name }}</span>
                </p>
              </div>
            </div>
          </template>

          <div v-else class="rounded-xl border border-zinc-200 bg-zinc-50 p-4">
            <p class="text-[10px] font-semibold tracking-[0.14em] text-zinc-500">NOMOR YANG DIPINDAI</p>
            <p class="mt-2 break-all font-mono text-lg font-semibold text-zinc-900">{{ scannedQueueNumber }}</p>
            <p class="mt-2 text-sm text-zinc-600">Data supir tidak tersedia untuk nomor antrean ini.</p>
          </div>

          <DialogFooter>
            <Button
              class="h-11 w-full rounded-xl bg-amber-300 font-semibold text-zinc-950 hover:bg-amber-200 sm:w-auto"
              @click="isScanResultDialogOpen = false"
            >
              Tutup & lanjut scan
            </Button>
          </DialogFooter>
        </div>
      </DialogContent>
    </Dialog>

    <Dialog v-model:open="isPinDialogOpen">
      <DialogContent class="border-black bg-white text-black shadow-2xl sm:max-w-sm">
        <DialogHeader>
          <DialogTitle class="flex items-center gap-2 text-black">
            <LockKeyhole class="size-4 text-amber-600" />
            Ganti Pos Gate
          </DialogTitle>
          <DialogDescription class="text-zinc-600">
            Masukkan PIN untuk menghapus konfigurasi pos saat ini.
          </DialogDescription>
        </DialogHeader>
        <form class="space-y-4" @submit.prevent="confirmChangeGate">
          <div class="space-y-2">
            <Label for="gate-change-pin" class="text-zinc-700">PIN</Label>
            <input
              id="gate-change-pin"
              v-model="pinValue"
              type="password"
              inputmode="numeric"
              autocomplete="off"
              maxlength="6"
              class="h-10 w-full rounded-lg border border-black bg-white px-3 font-mono text-zinc-950 outline-none focus-visible:black focus-visible:ring-2 focus-visible:ring-black"
              placeholder="Masukkan PIN 6 digit"
            />
            <p v-if="pinError" role="alert" class="text-sm text-rose-700">{{ pinError }}</p>
          </div>
          <DialogFooter>
            <Button type="submit">
              Verifikasi PIN
            </Button>
          </DialogFooter>
        </form>
      </DialogContent>
    </Dialog>
  </main>
</template>
