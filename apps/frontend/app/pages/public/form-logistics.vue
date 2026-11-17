<script setup lang="ts">
import {
  ArrowRight,
  Building2,
  CheckCircle2,
  Download,
  LoaderCircle,
  Package,
  Phone,
  Truck,
  UserRound,
  Warehouse,
} from 'lucide-vue-next'
import QRCode from 'qrcode'
import { Button } from '@/components/ui/button'
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from '@/components/ui/select'

definePageMeta({ alias: ['/public/logistik'] })

type VendorOption = {
  id: string
  name: string
}

const plantOptions = ['Jatake 1', 'Jatake 2', 'Jatake 3', 'Jatake 6']
const cargoOptions = ['Bahan Baku Kemasan', 'Karton Box', 'Finished Goods']
const generalVendorValue = '__general_vendor__'

const supabase = useSupabaseClient()
const vendors = ref<VendorOption[]>([])
const plantLocation = ref('')
const vendorSelection = ref('')
const driverName = ref('')
const driverPhone = ref('')
const licensePlate = ref('')
const estimatedArrivalAt = ref('')
const minimumEstimatedArrivalAt = ref('')
const cargoSelection = ref('')
const customCargoType = ref('')
const isLoadingVendors = ref(true)
const isSubmitting = ref(false)
const vendorError = ref('')
const formError = ref('')
const submittedQueueNumber = ref('')
const ticketCreatedAt = ref('')
const qrCodeDataUrl = ref('')
const ticketImageDataUrl = ref('')
const isTicketReady = ref(false)
const ticketError = ref('')

const cargoType = computed(() => (
  cargoSelection.value === 'other' ? customCargoType.value.trim() : cargoSelection.value
))

watch(submittedQueueNumber, async (queueNumber) => {
  isTicketReady.value = false
  qrCodeDataUrl.value = ''
  ticketImageDataUrl.value = ''
  ticketError.value = ''
  if (!queueNumber) return

  try {
    const dataUrl = await QRCode.toDataURL(queueNumber, {
      errorCorrectionLevel: 'M',
      margin: 4,
      width: 560,
      color: {
        dark: '#090909',
        light: '#FFFFFF',
      },
    })
    if (submittedQueueNumber.value !== queueNumber) return

    qrCodeDataUrl.value = dataUrl
    const ticketImage = await createTicketImage(
      dataUrl,
      queueNumber,
      ticketCreatedAt.value,
      plantLocation.value,
    )
    if (submittedQueueNumber.value !== queueNumber) return

    ticketImageDataUrl.value = ticketImage
    isTicketReady.value = true
  } catch (error) {
    if (submittedQueueNumber.value !== queueNumber) return
    console.error('Unable to generate branded logistics queue ticket', error)
    ticketError.value = qrCodeDataUrl.value
      ? 'QR code siap dipindai, tetapi gambar tiket berlogo gagal dibuat.'
      : 'QR code gagal dibuat. Simpan nomor antrean sebagai alternatif.'
  }
})

function getErrorMessage(error: unknown) {
  if (typeof error === 'object' && error !== null && 'data' in error) {
    const data = error.data
    if (typeof data === 'object' && data !== null && 'statusMessage' in data
      && typeof data.statusMessage === 'string') {
      return data.statusMessage
    }
  }
  if (error instanceof Error) return error.message
  return 'Terjadi kesalahan. Silakan coba kembali.'
}

function normalizePhone(phone: string) {
  const digits = phone.replace(/\D/g, '')
  if (digits.startsWith('0')) return `62${digits.slice(1)}`
  if (digits.startsWith('8')) return `62${digits}`
  return digits
}

function normalizeLicensePlate(value: string) {
  return value.toLocaleUpperCase('id-ID').trim().replace(/\s+/g, ' ')
}

function getJakartaDateTimeLocal(value: Date) {
  const parts = new Intl.DateTimeFormat('en-CA', {
    timeZone: 'Asia/Jakarta',
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
    hour: '2-digit',
    minute: '2-digit',
    hourCycle: 'h23',
  }).formatToParts(value)
  const getPart = (type: Intl.DateTimeFormatPartTypes) => (
    parts.find(part => part.type === type)?.value ?? ''
  )

  return `${getPart('year')}-${getPart('month')}-${getPart('day')}T${getPart('hour')}:${getPart('minute')}`
}

function getEstimatedArrivalIso(value: string) {
  if (!/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}$/.test(value)) return null

  const estimatedArrival = new Date(`${value}:00+07:00`)
  if (
    Number.isNaN(estimatedArrival.getTime())
    || getJakartaDateTimeLocal(estimatedArrival) !== value
    || estimatedArrival.getTime() <= Date.now()
  ) return null

  return estimatedArrival.toISOString()
}

function updateLicensePlate(value: string | number) {
  licensePlate.value = normalizeLicensePlate(String(value))
}

async function loadVendors() {
  isLoadingVendors.value = true
  vendorError.value = ''

  try {
    const result = await $fetch<{ vendors: VendorOption[] }>('/api/public/vendors')
    vendors.value = result.vendors
  } catch (error) {
    console.error('Unable to load vendors for the public logistics form', error)
    vendorError.value = getErrorMessage(error)
  } finally {
    isLoadingVendors.value = false
  }
}

function createQueueNumber() {
  const date = new Date().toLocaleDateString('sv-SE', { timeZone: 'Asia/Jakarta' }).replace(/-/g, '')
  return `TRK-${date}-${crypto.randomUUID().toUpperCase()}`
}

function loadTicketImage(source: string) {
  return new Promise<HTMLImageElement>((resolve, reject) => {
    const image = new Image()
    image.onload = () => resolve(image)
    image.onerror = () => reject(new Error('Gambar tiket gagal dimuat.'))
    image.src = source
  })
}

function formatTicketCreatedAt(value: string) {
  const formattedDate = new Intl.DateTimeFormat('id-ID', {
    dateStyle: 'long',
    timeStyle: 'short',
    timeZone: 'Asia/Jakarta',
  }).format(new Date(value))

  return `${formattedDate} WIB`
}

async function createTicketImage(
  qrCode: string,
  queueNumber: string,
  createdAt: string,
  destinationPlant: string,
) {
  const [logo, qrImage] = await Promise.all([
    loadTicketImage('/img/entrivahitam.png'),
    loadTicketImage(qrCode),
  ])
  const canvas = document.createElement('canvas')
  canvas.width = 960
  canvas.height = 1320
  const context = canvas.getContext('2d')
  if (!context) throw new Error('Canvas 2D tidak tersedia untuk membuat tiket.')

  context.fillStyle = '#F4F4F5'
  context.fillRect(0, 0, canvas.width, canvas.height)
  context.fillStyle = '#FFFFFF'
  context.fillRect(32, 32, 896, 1256)
  context.strokeStyle = '#E5E7EB'
  context.lineWidth = 2
  context.strokeRect(32, 32, 896, 1256)
  context.fillStyle = '#FACC15'
  context.fillRect(32, 32, 896, 12)

  const logoBox = { x: 82, y: 76, width: 90, height: 72 }
  const logoScale = Math.min(logoBox.width / logo.naturalWidth, logoBox.height / logo.naturalHeight)
  const logoWidth = logo.naturalWidth * logoScale
  const logoHeight = logo.naturalHeight * logoScale
  context.drawImage(
    logo,
    logoBox.x + (logoBox.width - logoWidth) / 2,
    logoBox.y + (logoBox.height - logoHeight) / 2,
    logoWidth,
    logoHeight,
  )

  context.textAlign = 'left'
  context.textBaseline = 'middle'
  context.fillStyle = '#090909'
  context.font = '700 44px Arial, sans-serif'
  context.fillText('ENTRIVA', 190, 108)
  context.fillStyle = '#171717'
  context.font = '600 17px Arial, sans-serif'
  context.fillText('PLANT ACCESS PORTAL', 192, 145)
  context.textAlign = 'right'
  context.font = '700 17px Arial, sans-serif'
  context.fillText('LOGISTICS PASS', 875, 118)

  context.strokeStyle = '#E5E7EB'
  context.beginPath()
  context.moveTo(82, 178)
  context.lineTo(878, 178)
  context.stroke()

  context.textAlign = 'center'
  context.fillStyle = '#090909'
  context.font = '700 32px Arial, sans-serif'
  context.fillText('TIKET ANTREAN KENDARAAN', 480, 226)
  context.fillStyle = '#52525B'
  context.font = '22px Arial, sans-serif'
  context.fillText('Tunjukkan QR code ini saat check-in di gate', 480, 267)

  context.fillStyle = '#FFFFFF'
  context.fillRect(180, 302, 600, 600)
  context.strokeStyle = '#E5E7EB'
  context.strokeRect(180, 302, 600, 600)
  context.imageSmoothingEnabled = false
  context.drawImage(qrImage, 200, 322, 560, 560)
  context.imageSmoothingEnabled = true

  context.fillStyle = '#090909'
  context.font = '700 24px monospace'
  context.fillText(queueNumber, 480, 950)
  context.fillStyle = '#71717A'
  context.font = '700 16px Arial, sans-serif'
  context.fillText('PLANT TUJUAN', 480, 1000)
  context.fillStyle = '#171717'
  context.font = '600 23px Arial, sans-serif'
  context.fillText(destinationPlant.toLocaleUpperCase('id-ID'), 480, 1035)
  context.fillStyle = '#71717A'
  context.font = '700 16px Arial, sans-serif'
  context.fillText('DIBUAT PADA', 480, 1083)
  context.fillStyle = '#171717'
  context.font = '600 21px Arial, sans-serif'
  context.fillText(formatTicketCreatedAt(createdAt), 480, 1118)

  context.fillStyle = '#FDE68A'
  context.fillRect(92, 1160, 776, 64)
  context.fillStyle = '#171717'
  context.font = '700 18px Arial, sans-serif'
  context.fillText('MENUNGGU PERSETUJUAN ADMIN LOGISTIK', 480, 1192)
  context.fillStyle = '#71717A'
  context.font = '16px Arial, sans-serif'
  context.fillText('QR code ini memuat nomor antrean kendaraan Anda.', 480, 1252)

  return canvas.toDataURL('image/png')
}

function resetForm() {
  plantLocation.value = ''
  vendorSelection.value = ''
  driverName.value = ''
  driverPhone.value = ''
  licensePlate.value = ''
  estimatedArrivalAt.value = ''
  minimumEstimatedArrivalAt.value = getJakartaDateTimeLocal(new Date())
  cargoSelection.value = ''
  customCargoType.value = ''
  formError.value = ''
  submittedQueueNumber.value = ''
  ticketCreatedAt.value = ''
}

function downloadQRCode() {
  if (!ticketImageDataUrl.value || !isTicketReady.value) return

  const link = document.createElement('a')
  link.href = ticketImageDataUrl.value
  link.download = `${submittedQueueNumber.value}-tiket-entriva.png`
  link.click()
}

async function submitRequest() {
  formError.value = ''

  const normalizedName = driverName.value.trim()
  const normalizedPhone = normalizePhone(driverPhone.value)
  const normalizedPlate = normalizeLicensePlate(licensePlate.value)
  const normalizedCargo = cargoType.value.trim()
  const estimatedArrivalIso = getEstimatedArrivalIso(estimatedArrivalAt.value)

  if (!plantOptions.includes(plantLocation.value)) {
    formError.value = 'Pilih plant tujuan terlebih dahulu.'
    return
  }
  if (normalizedName.length < 2 || normalizedName.length > 120) {
    formError.value = 'Nama supir harus berisi 2–120 karakter.'
    return
  }
  if (!/^628\d{8,11}$/.test(normalizedPhone)) {
    formError.value = 'Masukkan nomor WhatsApp Indonesia yang valid, misalnya 085711112222.'
    return
  }
  if (!/^[A-Z0-9]+(?: [A-Z0-9]+)*$/.test(normalizedPlate) || normalizedPlate.length > 12) {
    formError.value = 'Masukkan nomor polisi yang valid, misalnya B 9876 UZX.'
    return
  }
  if (!estimatedArrivalIso) {
    formError.value = 'Pilih estimasi kedatangan di plant dengan tanggal dan waktu yang akan datang (WIB).'
    return
  }
  if (!normalizedCargo || normalizedCargo.length > 120) {
    formError.value = 'Jenis muatan wajib diisi dan maksimal 120 karakter.'
    return
  }

  isSubmitting.value = true

  try {
    const queueNumber = createQueueNumber()
    const { error } = await supabase
      .from('logistics_queues')
      .insert({
        queue_number: queueNumber,
        plant_location: plantLocation.value,
        vendor_id: vendorSelection.value && vendorSelection.value !== generalVendorValue
          ? vendorSelection.value
          : null,
        driver_name: normalizedName,
        driver_phone: normalizedPhone,
        license_plate: normalizedPlate,
        estimated_arrival_at: estimatedArrivalIso,
        cargo_type: normalizedCargo,
        status: 'pending',
      })

    if (error) throw error
    ticketCreatedAt.value = new Date().toISOString()
    submittedQueueNumber.value = queueNumber
  } catch (error) {
    console.error('Unable to submit public logistics request', error)
    formError.value = getErrorMessage(error)
  } finally {
    isSubmitting.value = false
  }
}

onMounted(() => {
  minimumEstimatedArrivalAt.value = getJakartaDateTimeLocal(new Date())
  void loadVendors()
})
</script>

<template>
  <main class="min-h-screen bg-[#f1f2f4] px-4 py-6 sm:px-6 lg:flex lg:items-center lg:py-10">
    <div class="mx-auto w-full max-w-[1180px] overflow-hidden rounded-[28px] border border-white bg-white shadow-2xl shadow-slate-900/10">
      <div class="grid lg:grid-cols-[0.9fr_1.1fr]">
        <aside class="relative isolate flex min-h-[360px] flex-col justify-between overflow-hidden bg-[#171717] px-6 py-7 text-white sm:min-h-[420px] sm:px-9 sm:py-9 lg:min-h-[760px] lg:px-11 lg:py-10">
          <img
            src="/img/bgformlogistic.webp"
            alt=""
            class="absolute inset-0 -z-10 size-full object-cover"
          />
          <div class="absolute inset-0 -z-10 bg-gradient-to-br from-[#171717]/45 via-[#171717]/55 to-[#171717]/90" />

          <div class="inline-flex w-fit items-center gap-2 rounded-full border border-white/20 bg-black/20 px-3 py-1.5 text-xs font-semibold tracking-wide text-white backdrop-blur-sm">
            <Truck class="size-4 text-amber-300" />
            LOGISTICS PORTAL
          </div>

          <div class="relative mt-12 max-w-lg sm:mt-16 lg:mt-0">
            <h1 class="text-3xl font-bold leading-tight tracking-tight sm:text-4xl">
              Antrean logistik
              <span class="text-amber-300">lebih terarah.</span>
            </h1>
            <p class="mt-4 max-w-md text-sm leading-6 text-slate-100/85 sm:text-base">
              Kirim informasi kendaraan dan muatan sebelum tiba, agar tim plant dapat menyiapkan proses penerimaan dengan lebih baik.
            </p>

            <div class="mt-8 space-y-4">
              <div class="flex items-center gap-3">
                <span class="flex size-9 shrink-0 items-center justify-center rounded-full border border-white/20 bg-white/10 text-xs font-semibold">01</span>
                <p class="text-sm text-white/90">Pilih plant tujuan</p>
              </div>
              <div class="flex items-center gap-3">
                <span class="flex size-9 shrink-0 items-center justify-center rounded-full border border-white/20 bg-white/10 text-xs font-semibold">02</span>
                <p class="text-sm text-white/90">Lengkapi detail kendaraan</p>
              </div>
              <div class="flex items-center gap-3">
                <span class="flex size-9 shrink-0 items-center justify-center rounded-full border border-amber-300/50 bg-amber-300 text-xs font-bold text-slate-950">03</span>
                <p class="text-sm font-medium text-white">Tunggu pemeriksaan admin</p>
              </div>
            </div>
          </div>

          <p class="mt-8 text-xs text-white/70">Jatake 1 · Jatake 2 · Jatake 3 · Jatake 6</p>
        </aside>

        <section class="px-5 py-8 sm:px-10 sm:py-10 lg:px-14 lg:py-12">
          <div class="mx-auto max-w-md">
            <header class="mb-8 text-center">
              <div class="mb-5 flex items-center justify-center gap-2.5">
                <span class="flex size-10 items-center justify-center rounded-xl bg-[#171717]">
                  <img src="/img/entrivaputih.png" alt="Logo Entriva" class="h-6 w-auto object-contain" />
                </span>
                <span class="text-base font-bold tracking-[0.16em] text-slate-900">ENTRIVA</span>
              </div>
              <p class="text-xs font-semibold uppercase tracking-[0.16em] text-slate-500">Pengajuan kendaraan</p>
              <h2 class="mt-2 text-2xl font-bold tracking-tight text-slate-950 sm:text-3xl">
                Form antrean logistik
              </h2>
              <p class="mt-2 text-sm leading-relaxed text-slate-500">
                Isi data berikut dengan benar untuk mengajukan antrean.
              </p>
            </header>

            <Card
              v-if="submittedQueueNumber"
              class="overflow-hidden rounded-2xl border-[#171717]/15 bg-white py-0 text-[#090909] shadow-sm"
            >
              <div class="h-1.5 bg-[#FACC15]" />
              <CardHeader class="gap-3 px-5 pt-5 pb-0">
                <div class="flex items-start gap-3">
                  <span class="flex size-11 shrink-0 items-center justify-center rounded-xl bg-[#171717] text-[#FACC15]">
                    <CheckCircle2 class="size-5" />
                  </span>
                  <div class="space-y-1">
                    <CardTitle class="text-xl text-[#090909]">Pengajuan berhasil dikirim</CardTitle>
                    <CardDescription class="text-sm leading-relaxed text-slate-600">
                      Tunjukkan QR code ini di gate untuk check-in.
                    </CardDescription>
                  </div>
                </div>
              </CardHeader>
              <CardContent class="space-y-4 px-5 pt-4 pb-5">
                <div class="rounded-xl border border-[#FACC15]/60 bg-[#FDE68A]/30 p-4">
                  <div class="mt-3 flex min-h-64 items-center justify-center overflow-hidden rounded-lg border border-[#171717]/10 bg-white">
                    <img
                      v-if="ticketImageDataUrl"
                      :src="ticketImageDataUrl"
                      role="img"
                      aria-label="Tiket QR code Entriva"
                      class="h-auto w-full"
                    />
                    <img
                      v-else-if="qrCodeDataUrl"
                      :src="qrCodeDataUrl"
                      role="img"
                      aria-label="QR code nomor antrean"
                      class="m-4 size-56 max-w-full object-contain sm:size-60"
                    />
                    <LoaderCircle v-else-if="!ticketError" class="size-5 animate-spin text-[#171717]" />
                  </div>
                  <p v-if="!ticketImageDataUrl" class="mt-3 break-all text-center font-mono text-sm font-semibold text-[#090909]">
                    {{ submittedQueueNumber }}
                  </p>
                </div>
                <p
                  v-if="ticketError"
                  role="alert"
                  class="text-center text-xs leading-relaxed text-red-700"
                >
                  {{ ticketError }}
                </p>
                <div class="flex items-start gap-2 rounded-lg border border-[#171717]/10 px-3 py-2.5">
                  <CheckCircle2 class="mt-0.5 size-4 shrink-0 text-[#171717]" />
                  <p class="text-xs leading-relaxed text-slate-600">
                    Pengajuan menunggu persetujuan admin logistik. QR code dapat diunduh atau ditunjukkan dari layar ponsel.
                  </p>
                </div>
                <div class="grid gap-2 sm:grid-cols-2">
                  <Button
                    type="button"
                    :disabled="!isTicketReady"
                    class="h-11 bg-[#171717] text-white hover:bg-[#090909] disabled:opacity-50"
                    @click="downloadQRCode"
                  >
                    <Download class="size-4" />
                    Unduh QR code
                  </Button>
                  <Button
                    type="button"
                    variant="outline"
                    class="h-11 border-[#171717]/20 text-[#171717] hover:bg-[#FDE68A]/40"
                    @click="resetForm"
                  >
                    Buat pengajuan baru
                    <ArrowRight class="size-4" />
                  </Button>
                </div>
              </CardContent>
            </Card>

            <form v-else class="space-y-5" @submit.prevent="submitRequest">
              <div class="space-y-2">
                <Label for="plant-location" class="text-sm font-medium text-slate-700">
                  Plant tujuan <span class="text-amber-600">*</span>
                </Label>
                <div class="relative">
                  <Building2 class="pointer-events-none absolute left-3.5 top-1/2 z-10 size-4 -translate-y-1/2 text-slate-400" />
                  <Select v-model="plantLocation">
                    <SelectTrigger
                      id="plant-location"
                      class="h-12 w-full rounded-xl border-slate-200 bg-slate-50 pl-10 text-slate-900 focus:ring-amber-400/30 data-[placeholder]:text-slate-400"
                      aria-label="Pilih plant tujuan"
                    >
                      <SelectValue placeholder="Pilih plant" />
                    </SelectTrigger>
                    <SelectContent class="border-slate-200 bg-white text-slate-900">
                      <SelectItem v-for="plant in plantOptions" :key="plant" :value="plant">
                        {{ plant }}
                      </SelectItem>
                    </SelectContent>
                  </Select>
                </div>
              </div>

              <div class="space-y-2">
                <Label for="vendor" class="text-sm font-medium text-slate-700">
                  Perusahaan / vendor <span class="text-xs font-normal text-slate-400">(opsional)</span>
                </Label>
                <div class="relative">
                  <Warehouse class="pointer-events-none absolute left-3.5 top-1/2 z-10 size-4 -translate-y-1/2 text-slate-400" />
                  <Select v-model="vendorSelection">
                    <SelectTrigger
                      id="vendor"
                      class="h-12 w-full rounded-xl border-slate-200 bg-slate-50 pl-10 text-slate-900 focus:ring-amber-400/30 data-[placeholder]:text-slate-400"
                      aria-label="Pilih perusahaan atau vendor"
                    >
                      <SelectValue placeholder="Pilih vendor atau lewati" />
                    </SelectTrigger>
                    <SelectContent class="border-slate-200 bg-white text-slate-900">
                      <SelectItem :value="generalVendorValue">Vendor umum / lainnya</SelectItem>
                      <SelectItem v-for="vendor in vendors" :key="vendor.id" :value="vendor.id">
                        {{ vendor.name }}
                      </SelectItem>
                    </SelectContent>
                  </Select>
                </div>
                <p v-if="isLoadingVendors" class="text-xs text-slate-500">Memuat daftar vendor…</p>
                <p v-else-if="vendorError" role="status" class="text-xs text-amber-700">
                  Daftar vendor tidak tersedia. Pilih vendor umum atau lanjutkan tanpa vendor.
                </p>
                <p v-else class="text-xs text-slate-500">
                  Pilih vendor terdaftar atau vendor umum jika belum terdaftar.
                </p>
              </div>

              <div class="space-y-2">
                <Label for="driver-name" class="text-sm font-medium text-slate-700">
                  Nama lengkap supir <span class="text-amber-600">*</span>
                </Label>
                <div class="relative">
                  <UserRound class="pointer-events-none absolute left-3.5 top-1/2 size-4 -translate-y-1/2 text-slate-400" />
                  <Input
                    id="driver-name"
                    v-model="driverName"
                    autocomplete="name"
                    maxlength="120"
                    placeholder="Contoh: Slamet Widodo"
                    required
                    class="h-12 rounded-xl border-slate-200 bg-slate-50 pl-10 text-slate-900 placeholder:text-slate-400 focus-visible:border-amber-400 focus-visible:ring-amber-400/30"
                  />
                </div>
              </div>

              <div class="space-y-2">
                <Label for="driver-phone" class="text-sm font-medium text-slate-700">
                  Nomor WhatsApp aktif <span class="text-amber-600">*</span>
                </Label>
                <div class="relative">
                  <Phone class="pointer-events-none absolute left-3.5 top-1/2 size-4 -translate-y-1/2 text-slate-400" />
                  <Input
                    id="driver-phone"
                    v-model="driverPhone"
                    type="tel"
                    inputmode="tel"
                    autocomplete="tel"
                    maxlength="24"
                    placeholder="085711112222"
                    required
                    class="h-12 rounded-xl border-slate-200 bg-slate-50 pl-10 text-slate-900 placeholder:text-slate-400 focus-visible:border-amber-400 focus-visible:ring-amber-400/30"
                  />
                </div>
                <p class="text-xs text-slate-500">Nomor akan disimpan dengan awalan 62.</p>
              </div>

              <div class="space-y-2">
                <Label for="license-plate" class="text-sm font-medium text-slate-700">
                  Nomor polisi <span class="text-amber-600">*</span>
                </Label>
                <div class="relative">
                  <Truck class="pointer-events-none absolute left-3.5 top-1/2 size-4 -translate-y-1/2 text-slate-400" />
                  <Input
                    id="license-plate"
                    :model-value="licensePlate"
                    autocomplete="off"
                    maxlength="12"
                    placeholder="B 9876 UZX"
                    required
                    class="h-12 rounded-xl border-slate-200 bg-slate-50 pl-10 text-slate-900 placeholder:text-slate-400 focus-visible:border-amber-400 focus-visible:ring-amber-400/30"
                    @update:model-value="updateLicensePlate"
                  />
                </div>
                <p class="text-xs text-slate-500">Otomatis menjadi huruf kapital.</p>
              </div>

              <div class="space-y-2">
                <Label for="estimated-arrival" class="text-sm font-medium text-slate-700">
                  Estimasi kedatangan ke plant (WIB) <span class="text-amber-600">*</span>
                </Label>
                <Input
                  id="estimated-arrival"
                  v-model="estimatedArrivalAt"
                  type="datetime-local"
                  :min="minimumEstimatedArrivalAt"
                  required
                  class="h-12 rounded-xl border-slate-200 bg-slate-50 text-slate-900 focus-visible:border-amber-400 focus-visible:ring-amber-400/30"
                />
                <p class="text-xs text-slate-500">
                  Isi perkiraan waktu tiba di plant tujuan, bukan waktu mengisi formulir.
                </p>
              </div>

              <div class="space-y-2">
                <Label for="cargo-type" class="text-sm font-medium text-slate-700">
                  Jenis muatan / barang <span class="text-amber-600">*</span>
                </Label>
                <div class="relative">
                  <Package class="pointer-events-none absolute left-3.5 top-1/2 z-10 size-4 -translate-y-1/2 text-slate-400" />
                  <Select v-model="cargoSelection">
                    <SelectTrigger
                      id="cargo-type"
                      class="h-12 w-full rounded-xl border-slate-200 bg-slate-50 pl-10 text-slate-900 focus:ring-amber-400/30 data-[placeholder]:text-slate-400"
                      aria-label="Pilih jenis muatan"
                    >
                      <SelectValue placeholder="Pilih jenis muatan" />
                    </SelectTrigger>
                    <SelectContent class="border-slate-200 bg-white text-slate-900">
                      <SelectItem v-for="cargo in cargoOptions" :key="cargo" :value="cargo">
                        {{ cargo }}
                      </SelectItem>
                      <SelectItem value="other">Lainnya</SelectItem>
                    </SelectContent>
                  </Select>
                </div>
                <Input
                  v-if="cargoSelection === 'other'"
                  v-model="customCargoType"
                  maxlength="120"
                  aria-label="Masukkan jenis muatan lainnya"
                  placeholder="Tuliskan jenis muatan"
                  required
                  class="mt-2 h-12 rounded-xl border-slate-200 bg-slate-50 text-slate-900 placeholder:text-slate-400 focus-visible:border-amber-400 focus-visible:ring-amber-400/30"
                />
              </div>

              <p
                v-if="formError"
                role="alert"
                class="rounded-xl border border-rose-200 bg-rose-50 px-4 py-3 text-sm leading-relaxed text-rose-700"
              >
                {{ formError }}
              </p>

              <div class="space-y-4 border-t border-slate-100 pt-5">
                <p class="flex items-start gap-2 text-xs leading-relaxed text-slate-500">
                  <CheckCircle2 class="mt-0.5 size-4 shrink-0 text-emerald-600" />
                  Pengajuan baru berstatus menunggu persetujuan admin logistik.
                </p>
                <Button
                  type="submit"
                  :disabled="isSubmitting"
                  class="h-12 w-full gap-2 rounded-xl bg-[#facc15] text-sm font-semibold text-slate-950 shadow-md shadow-amber-900/10 hover:bg-[#eab308] disabled:opacity-60"
                >
                  <LoaderCircle v-if="isSubmitting" class="size-4 animate-spin" />
                  <template v-else>
                    Kirim pengajuan
                    <ArrowRight class="size-4" />
                  </template>
                  <span v-if="isSubmitting">Mengirim…</span>
                </Button>
              </div>
            </form>
          </div>
        </section>
      </div>
    </div>
  </main>
</template>