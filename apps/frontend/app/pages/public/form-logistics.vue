<script setup lang="ts">
import {
  ArrowRight,
  Building2,
  CheckCircle2,
  LoaderCircle,
  Package,
  Phone,
  Truck,
  UserRound,
  Warehouse,
} from 'lucide-vue-next'
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
const cargoSelection = ref('')
const customCargoType = ref('')
const isLoadingVendors = ref(true)
const isSubmitting = ref(false)
const vendorError = ref('')
const formError = ref('')
const submittedQueueNumber = ref('')

const cargoType = computed(() => (
  cargoSelection.value === 'other' ? customCargoType.value.trim() : cargoSelection.value
))

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

function resetForm() {
  plantLocation.value = ''
  vendorSelection.value = ''
  driverName.value = ''
  driverPhone.value = ''
  licensePlate.value = ''
  cargoSelection.value = ''
  customCargoType.value = ''
  formError.value = ''
  submittedQueueNumber.value = ''
}

async function submitRequest() {
  formError.value = ''

  const normalizedName = driverName.value.trim()
  const normalizedPhone = normalizePhone(driverPhone.value)
  const normalizedPlate = normalizeLicensePlate(licensePlate.value)
  const normalizedCargo = cargoType.value.trim()

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
        cargo_type: normalizedCargo,
        status: 'pending',
      })

    if (error) throw error
    submittedQueueNumber.value = queueNumber
  } catch (error) {
    console.error('Unable to submit public logistics request', error)
    formError.value = getErrorMessage(error)
  } finally {
    isSubmitting.value = false
  }
}

onMounted(loadVendors)
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

            <Card v-if="submittedQueueNumber" class="border-emerald-200 bg-emerald-50/70 shadow-none">
              <CardHeader class="items-center text-center">
                <span class="flex size-12 items-center justify-center rounded-full bg-emerald-100 text-emerald-700">
                  <CheckCircle2 class="size-6" />
                </span>
                <CardTitle class="text-xl text-slate-900">Pengajuan berhasil dikirim</CardTitle>
                <CardDescription class="text-slate-600">
                  Simpan nomor antrean ini. Pengajuan menunggu pemeriksaan admin logistik.
                </CardDescription>
              </CardHeader>
              <CardContent class="space-y-4 text-center">
                <p class="rounded-xl border border-emerald-200 bg-white px-4 py-3 font-mono text-sm font-semibold text-slate-900">
                  {{ submittedQueueNumber }}
                </p>
                <Button
                  type="button"
                  variant="outline"
                  class="border-slate-200 text-slate-700 hover:bg-slate-100"
                  @click="resetForm"
                >
                  Buat pengajuan lain
                  <ArrowRight class="size-4" />
                </Button>
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