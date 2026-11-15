<script setup lang="ts">
import { Building2, LoaderCircle, Plus, RefreshCw } from 'lucide-vue-next'
import { Button } from '@/components/ui/button'
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from '@/components/ui/table'

definePageMeta({ layout: 'dashboard' })

type VendorRecord = {
  id: string
  name: string
  company_code: string | null
  contact_person: string | null
  phone_number: string | null
  created_at: string | null
}

const supabase = useSupabaseClient()
const { showSuccess } = useSuccessModal()
const vendors = ref<VendorRecord[]>([])
const vendorName = ref('')
const companyCode = ref('')
const contactPerson = ref('')
const phoneNumber = ref('')
const isLoading = ref(true)
const isSubmitting = ref(false)
const pageError = ref('')
const formError = ref('')

onMounted(() => {
  void loadVendors()
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
  return 'Terjadi kesalahan yang tidak diketahui.'
}

async function loadVendors() {
  isLoading.value = true
  pageError.value = ''

  try {
    const { data: authData, error: authError } = await supabase.auth.getUser()
    if (authError) throw authError
    if (!authData.user) throw new Error('Sesi pengguna tidak ditemukan. Silakan masuk kembali.')

    const { data, error } = await supabase
      .from('vendors')
      .select('id, name, company_code, contact_person, phone_number, created_at')
      .order('name', { ascending: true })

    if (error) throw error
    vendors.value = data ?? []
  } catch (error) {
    console.error('Unable to load vendors', error)
    pageError.value = getErrorMessage(error)
  } finally {
    isLoading.value = false
  }
}

async function createVendor() {
  isSubmitting.value = true
  formError.value = ''

  try {
    const response = await $fetch<{ vendor: VendorRecord }>('/api/admin-logistics/vendors', {
      method: 'POST',
      body: {
        name: vendorName.value,
        company_code: companyCode.value,
        contact_person: contactPerson.value,
        phone_number: phoneNumber.value,
      },
    })

    vendors.value = [...vendors.value, response.vendor]
      .sort((first, second) => first.name.localeCompare(second.name))
    showSuccess(`Vendor ${response.vendor.name} berhasil ditambahkan.`)
    vendorName.value = ''
    companyCode.value = ''
    contactPerson.value = ''
    phoneNumber.value = ''
  } catch (error) {
    console.error('Unable to create vendor', error)
    formError.value = getErrorMessage(error)
  } finally {
    isSubmitting.value = false
  }
}
</script>

<template>
  <div class="space-y-6">
    <div class="flex flex-wrap items-end justify-between gap-4">
      <div>
        <p class="text-sm text-muted-foreground">Logistics operations</p>
        <h1 class="text-3xl font-semibold tracking-tight">Vendor</h1>
      </div>
      <Button variant="outline" :disabled="isLoading || isSubmitting" @click="loadVendors">
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

    <div class="grid gap-6 xl:grid-cols-[minmax(0,1fr)_minmax(0,1.5fr)]">
      <Card class="h-fit">
        <CardHeader>
          <CardTitle class="flex items-center gap-2"><Plus class="size-5" /> Tambah vendor</CardTitle>
          <CardDescription>Data vendor tersimpan di database dan dapat dipilih pada pengajuan logistik.</CardDescription>
        </CardHeader>
        <CardContent>
          <form class="space-y-4" @submit.prevent="createVendor">
            <div class="space-y-2">
              <Label for="vendor-name">Nama perusahaan</Label>
              <Input id="vendor-name" v-model="vendorName" maxlength="160" required />
            </div>
            <div class="space-y-2">
              <Label for="vendor-company-code">Kode perusahaan <span class="text-muted-foreground">(opsional)</span></Label>
              <Input id="vendor-company-code" v-model="companyCode" maxlength="80" />
            </div>
            <div class="space-y-2">
              <Label for="vendor-contact">Nama kontak <span class="text-muted-foreground">(opsional)</span></Label>
              <Input id="vendor-contact" v-model="contactPerson" maxlength="120" />
            </div>
            <div class="space-y-2">
              <Label for="vendor-phone">Nomor telepon <span class="text-muted-foreground">(opsional)</span></Label>
              <Input id="vendor-phone" v-model="phoneNumber" type="tel" maxlength="40" />
            </div>
            <p v-if="formError" role="alert" class="text-sm text-red-600 dark:text-red-400">
              {{ formError }}
            </p>
            <Button class="w-full" type="submit" :disabled="isSubmitting || isLoading">
              <LoaderCircle v-if="isSubmitting" class="size-4 animate-spin" />
              {{ isSubmitting ? 'Menyimpan...' : 'Simpan vendor' }}
            </Button>
          </form>
        </CardContent>
      </Card>

      <Card>
        <CardHeader>
          <CardTitle class="flex items-center gap-2"><Building2 class="size-5" /> Vendor terdaftar</CardTitle>
          <CardDescription>
            {{ vendors.length }} vendor tersimpan. Kode perusahaan, jika diisi, harus unik.
          </CardDescription>
        </CardHeader>
        <CardContent>
          <Table>
            <TableHeader>
              <TableRow>
                <TableHead>Perusahaan</TableHead>
                <TableHead>Kode</TableHead>
                <TableHead>Kontak</TableHead>
                <TableHead>Telepon</TableHead>
              </TableRow>
            </TableHeader>
            <TableBody>
              <TableRow v-if="isLoading">
                <TableCell colspan="4" class="py-8 text-center text-muted-foreground">
                  <LoaderCircle class="mr-2 inline size-4 animate-spin" />
                  Memuat vendor...
                </TableCell>
              </TableRow>
              <TableRow v-else-if="pageError">
                <TableCell colspan="4" class="py-8 text-center text-muted-foreground">
                  Data vendor tidak dapat ditampilkan.
                </TableCell>
              </TableRow>
              <TableRow v-else-if="vendors.length === 0">
                <TableCell colspan="4" class="py-8 text-center text-muted-foreground">
                  Belum ada vendor yang terdaftar.
                </TableCell>
              </TableRow>
              <TableRow v-for="vendor in vendors" v-else :key="vendor.id">
                <TableCell class="font-medium">{{ vendor.name }}</TableCell>
                <TableCell>{{ vendor.company_code || '—' }}</TableCell>
                <TableCell>{{ vendor.contact_person || '—' }}</TableCell>
                <TableCell>{{ vendor.phone_number || '—' }}</TableCell>
              </TableRow>
            </TableBody>
          </Table>
        </CardContent>
      </Card>
    </div>
  </div>
</template>
