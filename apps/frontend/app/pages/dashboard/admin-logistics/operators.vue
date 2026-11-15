<script setup lang="ts">
import { KeyRound, LoaderCircle, RefreshCw, ShieldOff, Trash2, UserRoundPlus, Users } from 'lucide-vue-next'
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
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from '@/components/ui/table'

definePageMeta({ layout: 'dashboard' })

type OperatorRecord = {
  id: string
  email: string
  full_name: string
  phone_number: string | null
  role: 'operator_logistics'
  plant_location: string
  created_at: string | null
  is_active: boolean
}

const { showSuccess } = useSuccessModal()
const operators = ref<OperatorRecord[]>([])
const plantLocation = ref('')
const fullName = ref('')
const email = ref('')
const phoneNumber = ref('')
const password = ref('')
const selectedOperator = ref<OperatorRecord | null>(null)
const isDetailDialogOpen = ref(false)
const newOperatorPassword = ref('')
const confirmOperatorPassword = ref('')
const deleteConfirmationEmail = ref('')
const isDeleteConfirmationOpen = ref(false)
const isLoading = ref(true)
const isSubmitting = ref(false)
const pendingAction = ref<'reset-password' | 'status' | 'delete' | null>(null)
const pageError = ref('')
const formError = ref('')
const actionError = ref('')

const isOperatorActionBusy = computed(() => pendingAction.value !== null)

onMounted(() => {
  void loadOperators()
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

async function loadOperators() {
  isLoading.value = true
  pageError.value = ''

  try {
    const response = await $fetch<{ plantLocation: string, operators: OperatorRecord[] }>(
      '/api/admin-logistics/operators',
    )
    plantLocation.value = response.plantLocation
    operators.value = response.operators
  } catch (error) {
    console.error('Unable to load logistics operators', error)
    pageError.value = getErrorMessage(error)
  } finally {
    isLoading.value = false
  }
}

async function createOperator() {
  isSubmitting.value = true
  formError.value = ''

  try {
    const response = await $fetch<{ operator: Omit<OperatorRecord, 'is_active'> }>('/api/admin-logistics/operators', {
      method: 'POST',
      body: {
        email: email.value,
        full_name: fullName.value,
        phone_number: phoneNumber.value,
        password: password.value,
      },
    })

    operators.value = [...operators.value, { ...response.operator, is_active: true }]
      .sort((first, second) => first.full_name.localeCompare(second.full_name))
    showSuccess(`Akun operator ${response.operator.full_name} berhasil dibuat.`)
    fullName.value = ''
    email.value = ''
    phoneNumber.value = ''
    password.value = ''
  } catch (error) {
    console.error('Unable to create logistics operator', error)
    formError.value = getErrorMessage(error)
  } finally {
    isSubmitting.value = false
  }
}

function openOperatorDetails(operator: OperatorRecord) {
  selectedOperator.value = operator
  newOperatorPassword.value = ''
  confirmOperatorPassword.value = ''
  deleteConfirmationEmail.value = ''
  isDeleteConfirmationOpen.value = false
  actionError.value = ''
  isDetailDialogOpen.value = true
}

function handleDetailsDialogOpenChange(open: boolean) {
  if (!open && isOperatorActionBusy.value) return
  isDetailDialogOpen.value = open
  if (!open) {
    selectedOperator.value = null
    isDeleteConfirmationOpen.value = false
    actionError.value = ''
  }
}

async function resetOperatorPassword() {
  const operator = selectedOperator.value
  if (!operator) return
  if (newOperatorPassword.value.length < 8 || newOperatorPassword.value.length > 128) {
    actionError.value = 'Kata sandi harus terdiri dari 8–128 karakter.'
    return
  }
  if (newOperatorPassword.value !== confirmOperatorPassword.value) {
    actionError.value = 'Konfirmasi kata sandi tidak cocok.'
    return
  }

  pendingAction.value = 'reset-password'
  actionError.value = ''
  try {
    await $fetch(`/api/admin-logistics/operators/${encodeURIComponent(operator.id)}/password`, {
      method: 'PATCH',
      body: { password: newOperatorPassword.value },
    })
    newOperatorPassword.value = ''
    confirmOperatorPassword.value = ''
    showSuccess(`Kata sandi akun ${operator.full_name} berhasil direset.`)
  } catch (error) {
    console.error('Unable to reset logistics operator password', error)
    actionError.value = getErrorMessage(error)
  } finally {
    pendingAction.value = null
  }
}

async function toggleOperatorStatus() {
  const operator = selectedOperator.value
  if (!operator) return

  pendingAction.value = 'status'
  actionError.value = ''
  try {
    const response = await $fetch<{ is_active: boolean }>(
      `/api/admin-logistics/operators/${encodeURIComponent(operator.id)}/status`,
      {
        method: 'PATCH',
        body: { is_active: !operator.is_active },
      },
    )

    operators.value = operators.value.map(existing => (
      existing.id === operator.id ? { ...existing, is_active: response.is_active } : existing
    ))
    selectedOperator.value = { ...operator, is_active: response.is_active }
    showSuccess(`Akun ${operator.full_name} berhasil ${response.is_active ? 'diaktifkan' : 'dinonaktifkan'}.`)
  } catch (error) {
    console.error('Unable to update logistics operator status', error)
    actionError.value = getErrorMessage(error)
  } finally {
    pendingAction.value = null
  }
}

async function deleteOperator() {
  const operator = selectedOperator.value
  if (!operator || deleteConfirmationEmail.value.trim().toLowerCase() !== operator.email.toLowerCase()) return

  pendingAction.value = 'delete'
  actionError.value = ''
  try {
    await $fetch(`/api/admin-logistics/operators/${encodeURIComponent(operator.id)}`, {
      method: 'DELETE',
    })
    operators.value = operators.value.filter(existing => existing.id !== operator.id)
    selectedOperator.value = null
    isDeleteConfirmationOpen.value = false
    isDetailDialogOpen.value = false
    showSuccess(`Akun ${operator.full_name} berhasil dihapus.`)
  } catch (error) {
    console.error('Unable to delete logistics operator', error)
    actionError.value = getErrorMessage(error)
  } finally {
    pendingAction.value = null
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
        <h1 class="text-3xl font-semibold tracking-tight">Akun operator</h1>
      </div>
      <Button variant="outline" :disabled="isLoading || isSubmitting" @click="loadOperators">
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
          <CardTitle class="flex items-center gap-2"><UserRoundPlus class="size-5" /> Tambah akun operator</CardTitle>
          <CardDescription>
            Akun dibuat khusus untuk role Operator Yard dan plant {{ plantLocation || 'akun ini' }}.
          </CardDescription>
        </CardHeader>
        <CardContent>
          <form class="space-y-4" @submit.prevent="createOperator">
            <div class="space-y-2">
              <Label for="operator-name">Nama lengkap</Label>
              <Input id="operator-name" v-model="fullName" maxlength="120" autocomplete="name" required />
            </div>
            <div class="space-y-2">
              <Label for="operator-email">Email</Label>
              <Input id="operator-email" v-model="email" type="email" autocomplete="email" required />
            </div>
            <div class="space-y-2">
              <Label for="operator-phone">Nomor telepon</Label>
              <Input id="operator-phone" v-model="phoneNumber" type="tel" maxlength="40" autocomplete="tel" />
            </div>
            <div class="space-y-2">
              <Label for="operator-password">Kata sandi awal</Label>
              <Input
                id="operator-password"
                v-model="password"
                type="password"
                minlength="8"
                maxlength="128"
                autocomplete="new-password"
                required
              />
              <p class="text-xs text-muted-foreground">Minimal 8 karakter. Sampaikan kata sandi ini secara aman kepada operator.</p>
            </div>
            <p v-if="formError" role="alert" class="text-sm text-red-600 dark:text-red-400">
              {{ formError }}
            </p>
            <Button class="w-full" type="submit" :disabled="isSubmitting || isLoading || !plantLocation">
              <LoaderCircle v-if="isSubmitting" class="size-4 animate-spin" />
              {{ isSubmitting ? 'Membuat akun...' : 'Buat akun operator' }}
            </Button>
          </form>
        </CardContent>
      </Card>

      <Card>
        <CardHeader>
          <CardTitle class="flex items-center gap-2"><Users class="size-5" /> Operator terdaftar</CardTitle>
          <CardDescription>Daftar operator yang ditugaskan ke plant {{ plantLocation || 'akun ini' }}.</CardDescription>
        </CardHeader>
        <CardContent>
          <div class="overflow-x-auto">
            <Table>
              <TableHeader>
                <TableRow>
                  <TableHead>Nama</TableHead>
                  <TableHead>Email</TableHead>
                  <TableHead>Telepon</TableHead>
                  <TableHead>Status akun</TableHead>
                  <TableHead class="text-right">Aksi</TableHead>
                </TableRow>
              </TableHeader>
              <TableBody>
                <TableRow v-if="isLoading">
                  <TableCell colspan="5" class="py-8 text-center text-muted-foreground">
                    <LoaderCircle class="mr-2 inline size-4 animate-spin" />
                    Memuat operator...
                  </TableCell>
                </TableRow>
                <TableRow v-else-if="pageError">
                  <TableCell colspan="5" class="py-8 text-center text-muted-foreground">
                    Data operator tidak dapat ditampilkan.
                  </TableCell>
                </TableRow>
                <TableRow v-else-if="operators.length === 0">
                  <TableCell colspan="5" class="py-8 text-center text-muted-foreground">
                    Belum ada operator untuk plant ini.
                  </TableCell>
                </TableRow>
                <TableRow v-for="operator in operators" v-else :key="operator.id">
                  <TableCell class="font-medium">{{ operator.full_name }}</TableCell>
                  <TableCell>{{ operator.email }}</TableCell>
                  <TableCell>{{ operator.phone_number || '—' }}</TableCell>
                  <TableCell>
                    <Badge :variant="operator.is_active ? 'secondary' : 'outline'">
                      {{ operator.is_active ? 'Aktif' : 'Nonaktif' }}
                    </Badge>
                  </TableCell>
                  <TableCell class="text-right">
                    <Button
                      variant="outline"
                      size="sm"
                      :disabled="isOperatorActionBusy"
                      @click="openOperatorDetails(operator)"
                    >
                      Detail
                    </Button>
                  </TableCell>
                </TableRow>
              </TableBody>
            </Table>
          </div>
        </CardContent>
      </Card>
    </div>

    <Dialog :open="isDetailDialogOpen" @update:open="handleDetailsDialogOpenChange">
      <DialogContent class="max-h-[90vh] overflow-y-auto sm:max-w-xl">
        <DialogHeader>
          <DialogTitle>Detail akun operator</DialogTitle>
          <DialogDescription>
            Atur akses dan kata sandi {{ selectedOperator?.full_name || 'operator' }}.
          </DialogDescription>
        </DialogHeader>

        <template v-if="selectedOperator">
          <div class="rounded-xl border bg-muted/20 p-4">
            <div class="flex flex-wrap items-center justify-between gap-3">
              <div class="min-w-0">
                <p class="font-semibold">{{ selectedOperator.full_name }}</p>
                <p class="truncate text-sm text-muted-foreground">{{ selectedOperator.email }}</p>
                <p class="mt-1 text-xs text-muted-foreground">
                  {{ selectedOperator.phone_number || 'Telepon belum diisi' }} · {{ selectedOperator.plant_location }}
                </p>
              </div>
              <Badge :variant="selectedOperator.is_active ? 'secondary' : 'outline'">
                {{ selectedOperator.is_active ? 'Aktif' : 'Nonaktif' }}
              </Badge>
            </div>
          </div>

          <p v-if="actionError" role="alert" class="text-sm text-red-600 dark:text-red-400">
            {{ actionError }}
          </p>

          <section class="space-y-3 rounded-xl border p-4">
            <div class="flex items-center gap-2">
              <KeyRound class="size-4 text-muted-foreground" />
              <h3 class="font-medium">Reset kata sandi</h3>
            </div>
            <form class="space-y-3" @submit.prevent="resetOperatorPassword">
              <div class="space-y-2">
                <Label for="operator-new-password">Kata sandi baru</Label>
                <Input
                  id="operator-new-password"
                  v-model="newOperatorPassword"
                  type="password"
                  minlength="8"
                  maxlength="128"
                  autocomplete="new-password"
                  required
                />
              </div>
              <div class="space-y-2">
                <Label for="operator-confirm-password">Konfirmasi kata sandi</Label>
                <Input
                  id="operator-confirm-password"
                  v-model="confirmOperatorPassword"
                  type="password"
                  minlength="8"
                  maxlength="128"
                  autocomplete="new-password"
                  required
                />
              </div>
              <Button
                type="submit"
                variant="secondary"
                :disabled="isOperatorActionBusy || newOperatorPassword.length < 8 || newOperatorPassword !== confirmOperatorPassword"
              >
                <LoaderCircle v-if="pendingAction === 'reset-password'" class="size-4 animate-spin" />
                {{ pendingAction === 'reset-password' ? 'Mereset...' : 'Reset kata sandi' }}
              </Button>
            </form>
          </section>

          <section class="flex flex-wrap items-center justify-between gap-3 rounded-xl border p-4">
            <div class="flex items-center gap-2">
              <ShieldOff class="size-4 text-muted-foreground" />
              <div>
                <h3 class="font-medium">Status akun</h3>
                <p class="text-xs text-muted-foreground">
                  {{ selectedOperator.is_active ? 'Operator dapat masuk ke aplikasi.' : 'Operator tidak dapat masuk ke aplikasi.' }}
                </p>
              </div>
            </div>
            <Button
              :variant="selectedOperator.is_active ? 'destructive' : 'secondary'"
              :disabled="isOperatorActionBusy"
              @click="toggleOperatorStatus"
            >
              <LoaderCircle v-if="pendingAction === 'status'" class="size-4 animate-spin" />
              {{ pendingAction === 'status'
                ? 'Memproses...'
                : selectedOperator.is_active
                  ? 'Nonaktifkan akun'
                  : 'Aktifkan akun' }}
            </Button>
          </section>

          <section class="space-y-3 rounded-xl border border-destructive/30 p-4">
            <div class="flex items-center gap-2">
              <Trash2 class="size-4 text-destructive" />
              <h3 class="font-medium">Hapus akun</h3>
            </div>
            <p class="text-sm text-muted-foreground">
              Akun akan dihapus permanen. Riwayat persetujuan tetap menyimpan nama approver.
            </p>
            <Button
              v-if="!isDeleteConfirmationOpen"
              variant="destructive"
              :disabled="isOperatorActionBusy"
              @click="isDeleteConfirmationOpen = true"
            >
              Hapus akun operator
            </Button>
            <div v-else class="space-y-3">
              <p class="text-sm">
                Ketik email <span class="font-semibold">{{ selectedOperator.email }}</span> untuk mengonfirmasi.
              </p>
              <Input
                v-model="deleteConfirmationEmail"
                :disabled="isOperatorActionBusy"
                autocomplete="off"
                aria-label="Konfirmasi email untuk menghapus akun"
              />
              <div class="flex flex-wrap justify-end gap-2">
                <Button
                  variant="outline"
                  :disabled="isOperatorActionBusy"
                  @click="isDeleteConfirmationOpen = false"
                >
                  Batal
                </Button>
                <Button
                  variant="destructive"
                  :disabled="isOperatorActionBusy || deleteConfirmationEmail.trim().toLowerCase() !== selectedOperator.email.toLowerCase()"
                  @click="deleteOperator"
                >
                  <LoaderCircle v-if="pendingAction === 'delete'" class="size-4 animate-spin" />
                  {{ pendingAction === 'delete' ? 'Menghapus...' : 'Ya, hapus permanen' }}
                </Button>
              </div>
            </div>
          </section>
        </template>

        <DialogFooter>
          <Button variant="outline" :disabled="isOperatorActionBusy" @click="handleDetailsDialogOpenChange(false)">
            Tutup
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  </div>
</template>
