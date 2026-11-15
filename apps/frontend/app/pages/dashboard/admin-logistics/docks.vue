<script setup lang="ts">
import { Dock, LoaderCircle, Pencil, Plus, RefreshCw } from 'lucide-vue-next'
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

type DockRecord = {
  id: string
  name: string
  is_active: boolean | null
}

type ActiveQueueAssignment = {
  assigned_dock_id: string | null
  current_node_id: string | null
}

const supabase = useSupabaseClient()
const { showSuccess } = useSuccessModal()
const plantLocation = ref('')
const docks = ref<DockRecord[]>([])
const activeQueueAssignments = ref<ActiveQueueAssignment[]>([])
const isLoading = ref(true)
const isSavingDock = ref(false)
const togglingDockId = ref<string | null>(null)
const pageError = ref('')
const dialogError = ref('')
const isAddDialogOpen = ref(false)
const isRenameDialogOpen = ref(false)
const newDockName = ref('')
const dockToRename = ref<DockRecord | null>(null)
const renamedDockName = ref('')

const occupiedDockIds = computed(() => new Set(
  activeQueueAssignments.value
    .flatMap(queue => [queue.assigned_dock_id, queue.current_node_id])
    .filter((id): id is string => Boolean(id)),
))
const availableDockCount = computed(() => (
  docks.value.filter(dock => dock.is_active === true && !occupiedDockIds.value.has(dock.id)).length
))
const occupiedDockCount = computed(() => (
  docks.value.filter(dock => dock.is_active === true && occupiedDockIds.value.has(dock.id)).length
))

onMounted(() => {
  void loadDocks()
})

function getErrorMessage(error: unknown) {
  if (error instanceof Error) return error.message
  if (typeof error === 'object' && error !== null && 'message' in error && typeof error.message === 'string') {
    return error.message
  }
  return 'Data docking gagal dimuat.'
}

function isDockNameTaken(name: string, exceptId?: string) {
  const normalizedName = name.trim().toLowerCase()
  return docks.value.some(dock => (
    dock.id !== exceptId && dock.name.trim().toLowerCase() === normalizedName
  ))
}

async function ensureAuthenticated() {
  const { data, error } = await supabase.auth.getUser()
  if (error) throw error
  if (!data.user) throw new Error('Sesi pengguna tidak ditemukan. Silakan masuk kembali.')
}

async function loadActiveQueueAssignments(currentPlant: string) {
  const pageSize = 500
  const assignments: ActiveQueueAssignment[] = []

  for (let from = 0; ; from += pageSize) {
    const { data, error } = await supabase
      .from('logistics_queues')
      .select('assigned_dock_id, current_node_id')
      .eq('plant_location', currentPlant)
      .in('status', ['called_to_dock', 'unloading'])
      .range(from, from + pageSize - 1)

    if (error) throw error

    const page = data ?? []
    assignments.push(...page)
    if (page.length < pageSize) return assignments
  }
}

async function loadDocks() {
  isLoading.value = true
  pageError.value = ''

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
    const [dockResult, assignments] = await Promise.all([
      supabase
        .from('map_nodes')
        .select('id, name, is_active')
        .eq('plant_location', currentPlant)
        .eq('node_type', 'dock')
        .order('name', { ascending: true }),
      loadActiveQueueAssignments(currentPlant),
    ])

    if (dockResult.error) throw dockResult.error

    plantLocation.value = currentPlant
    docks.value = dockResult.data ?? []
    activeQueueAssignments.value = assignments
  } catch (error) {
    console.error('Unable to load dock management data', error)
    pageError.value = getErrorMessage(error)
  } finally {
    isLoading.value = false
  }
}

function openAddDialog() {
  newDockName.value = ''
  dialogError.value = ''
  isAddDialogOpen.value = true
}

function handleAddDialogOpenChange(open: boolean) {
  if (!open && isSavingDock.value) return
  isAddDialogOpen.value = open
  if (!open) dialogError.value = ''
}

function openRenameDialog(dock: DockRecord) {
  dockToRename.value = dock
  renamedDockName.value = dock.name
  dialogError.value = ''
  isRenameDialogOpen.value = true
}

function handleRenameDialogOpenChange(open: boolean) {
  if (!open && isSavingDock.value) return
  isRenameDialogOpen.value = open
  if (!open) {
    dockToRename.value = null
    dialogError.value = ''
  }
}

async function addDock() {
  const name = newDockName.value.trim()
  if (!name) {
    dialogError.value = 'Nama dock wajib diisi.'
    return
  }
  if (isDockNameTaken(name)) {
    dialogError.value = 'Nama dock sudah digunakan di plant ini.'
    return
  }

  isSavingDock.value = true
  dialogError.value = ''

  try {
    await ensureAuthenticated()
    const { data, error } = await supabase
      .from('map_nodes')
      .insert({
        name,
        plant_location: plantLocation.value,
        node_type: 'dock',
        is_active: true,
      })
      .select('id, name, is_active')
      .single()

    if (error) throw error

    docks.value = [...docks.value, data].sort((first, second) => first.name.localeCompare(second.name))
    isAddDialogOpen.value = false
    showSuccess(`Dock ${name} berhasil ditambahkan.`)
  } catch (error) {
    console.error('Unable to add dock', error)
    dialogError.value = getErrorMessage(error)
  } finally {
    isSavingDock.value = false
  }
}

async function renameDock() {
  const dock = dockToRename.value
  const name = renamedDockName.value.trim()
  if (!dock) return
  if (!name) {
    dialogError.value = 'Nama dock wajib diisi.'
    return
  }
  if (isDockNameTaken(name, dock.id)) {
    dialogError.value = 'Nama dock sudah digunakan di plant ini.'
    return
  }

  isSavingDock.value = true
  dialogError.value = ''

  try {
    await ensureAuthenticated()
    const { data, error } = await supabase
      .from('map_nodes')
      .update({ name })
      .eq('id', dock.id)
      .eq('plant_location', plantLocation.value)
      .eq('node_type', 'dock')
      .select('id, name, is_active')
      .maybeSingle()

    if (error) throw error
    if (!data) throw new Error('Dock tidak ditemukan. Muat ulang data dan coba lagi.')

    docks.value = docks.value
      .map(existingDock => existingDock.id === dock.id ? data : existingDock)
      .sort((first, second) => first.name.localeCompare(second.name))
    isRenameDialogOpen.value = false
    dockToRename.value = null
    showSuccess(`Nama dock berhasil diubah menjadi ${name}.`)
  } catch (error) {
    console.error('Unable to rename dock', error)
    dialogError.value = getErrorMessage(error)
  } finally {
    isSavingDock.value = false
  }
}

async function toggleDockAvailability(dock: DockRecord) {
  if (togglingDockId.value || isSavingDock.value) return

  const nextIsActive = dock.is_active !== true
  togglingDockId.value = dock.id
  pageError.value = ''

  try {
    await ensureAuthenticated()

    if (!nextIsActive) {
      const { data: occupiedQueue, error: occupancyError } = await supabase
        .from('logistics_queues')
        .select('id')
        .eq('plant_location', plantLocation.value)
        .in('status', ['called_to_dock', 'unloading'])
        .or(`assigned_dock_id.eq.${dock.id},current_node_id.eq.${dock.id}`)
        .limit(1)
        .maybeSingle()

      if (occupancyError) throw occupancyError
      if (occupiedQueue) throw new Error('Dock sedang digunakan kendaraan dan tidak dapat dinonaktifkan.')
    }

    const { data, error } = await supabase
      .from('map_nodes')
      .update({ is_active: nextIsActive })
      .eq('id', dock.id)
      .eq('plant_location', plantLocation.value)
      .eq('node_type', 'dock')
      .select('id, name, is_active')
      .maybeSingle()

    if (error) throw error
    if (!data) throw new Error('Dock tidak ditemukan. Muat ulang data dan coba lagi.')

    docks.value = docks.value.map(existingDock => existingDock.id === dock.id ? data : existingDock)
    showSuccess(`Dock ${dock.name} sekarang ${nextIsActive ? 'aktif' : 'nonaktif'}.`)
  } catch (error) {
    console.error('Unable to update dock availability', error)
    pageError.value = getErrorMessage(error)
  } finally {
    togglingDockId.value = null
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
        <h1 class="text-3xl font-semibold tracking-tight">Pengaturan docking</h1>
      </div>
      <div class="flex gap-2">
        <Button variant="outline" :disabled="isLoading || isSavingDock || togglingDockId !== null" @click="loadDocks">
          <RefreshCw class="size-4" :class="isLoading ? 'animate-spin' : ''" />
          Refresh
        </Button>
        <Button :disabled="isLoading || isSavingDock || !plantLocation" @click="openAddDialog">
          <Plus class="size-4" />
          Tambah dock
        </Button>
      </div>
    </div>

    <p
      v-if="pageError"
      role="alert"
      class="rounded-xl border border-red-500/20 bg-red-500/10 px-4 py-3 text-sm text-red-700 dark:text-red-300"
    >
      {{ pageError }}
    </p>

    <section class="grid gap-4 sm:grid-cols-3" aria-label="Ringkasan docking">
      <Card>
        <CardHeader>
          <CardDescription>Total dock</CardDescription>
          <CardTitle class="text-3xl">{{ isLoading || pageError ? '—' : docks.length }}</CardTitle>
        </CardHeader>
      </Card>
      <Card>
        <CardHeader>
          <CardDescription>Tersedia</CardDescription>
          <CardTitle class="text-3xl">{{ isLoading || pageError ? '—' : availableDockCount }}</CardTitle>
        </CardHeader>
      </Card>
      <Card>
        <CardHeader>
          <CardDescription>Sedang digunakan</CardDescription>
          <CardTitle class="text-3xl">{{ isLoading || pageError ? '—' : occupiedDockCount }}</CardTitle>
        </CardHeader>
      </Card>
    </section>

    <Card>
      <CardHeader>
        <CardTitle class="flex items-center gap-2"><Dock class="size-5" /> Dock di plant {{ plantLocation || 'akun' }}</CardTitle>
        <CardDescription>
          Kelola nama dan ketersediaan dock. Dock yang sedang ditempati kendaraan tidak dapat dinonaktifkan.
        </CardDescription>
      </CardHeader>
      <CardContent>
        <Table>
          <TableHeader>
            <TableRow>
              <TableHead>Nama dock</TableHead>
              <TableHead>Status</TableHead>
              <TableHead>Ketersediaan</TableHead>
              <TableHead class="text-right">Tindakan</TableHead>
            </TableRow>
          </TableHeader>
          <TableBody>
            <TableRow v-if="isLoading">
              <TableCell colspan="4" class="py-8 text-center text-muted-foreground">
                <LoaderCircle class="mr-2 inline size-4 animate-spin" />
                Memuat data dock...
              </TableCell>
            </TableRow>
            <TableRow v-else-if="pageError">
              <TableCell colspan="4" class="py-8 text-center text-muted-foreground">
                Data dock tidak dapat ditampilkan.
              </TableCell>
            </TableRow>
            <TableRow v-else-if="docks.length === 0">
              <TableCell colspan="4" class="py-8 text-center text-muted-foreground">
                Belum ada dock di plant ini. Tambahkan dock untuk mulai mengatur ketersediaannya.
              </TableCell>
            </TableRow>
            <TableRow v-for="dock in docks" v-else :key="dock.id">
              <TableCell class="font-medium">{{ dock.name }}</TableCell>
              <TableCell>
                <Badge :variant="dock.is_active === true ? 'secondary' : 'outline'">
                  {{ dock.is_active === true ? 'Aktif' : 'Nonaktif' }}
                </Badge>
              </TableCell>
              <TableCell>
                <span v-if="dock.is_active !== true">Tidak tersedia</span>
                <span v-else-if="occupiedDockIds.has(dock.id)">Sedang digunakan</span>
                <span v-else>Tersedia</span>
              </TableCell>
              <TableCell>
                <div class="flex justify-end gap-2">
                  <Button
                    variant="outline"
                    size="sm"
                    :disabled="isSavingDock || togglingDockId !== null"
                    @click="openRenameDialog(dock)"
                  >
                    <Pencil class="size-4" />
                    Ganti nama
                  </Button>
                  <Button
                    :variant="dock.is_active === true ? 'destructive' : 'secondary'"
                    size="sm"
                    :disabled="isLoading || isSavingDock || togglingDockId !== null || (dock.is_active === true && occupiedDockIds.has(dock.id))"
                    :title="dock.is_active === true && occupiedDockIds.has(dock.id)
                      ? 'Dock sedang digunakan kendaraan'
                      : undefined"
                    @click="toggleDockAvailability(dock)"
                  >
                    <LoaderCircle v-if="togglingDockId === dock.id" class="size-4 animate-spin" />
                    {{ dock.is_active === true ? 'Nonaktifkan' : 'Aktifkan' }}
                  </Button>
                </div>
              </TableCell>
            </TableRow>
          </TableBody>
        </Table>
      </CardContent>
    </Card>

    <Dialog :open="isAddDialogOpen" @update:open="handleAddDialogOpenChange">
      <DialogContent :show-close-button="!isSavingDock">
        <DialogHeader>
          <DialogTitle>Tambah dock</DialogTitle>
          <DialogDescription>Dock akan ditambahkan ke plant {{ plantLocation }} dalam keadaan aktif.</DialogDescription>
        </DialogHeader>
        <form class="space-y-4" @submit.prevent="addDock">
          <div class="space-y-2">
            <Label for="new-dock-name">Nama dock</Label>
            <Input id="new-dock-name" v-model="newDockName" maxlength="120" required autofocus />
          </div>
          <p v-if="dialogError" role="alert" class="text-sm text-red-600 dark:text-red-400">
            {{ dialogError }}
          </p>
          <DialogFooter>
            <Button type="button" variant="outline" :disabled="isSavingDock" @click="handleAddDialogOpenChange(false)">
              Batal
            </Button>
            <Button type="submit" :disabled="isSavingDock || !newDockName.trim()">
              <LoaderCircle v-if="isSavingDock" class="size-4 animate-spin" />
              {{ isSavingDock ? 'Menyimpan...' : 'Simpan dock' }}
            </Button>
          </DialogFooter>
        </form>
      </DialogContent>
    </Dialog>

    <Dialog :open="isRenameDialogOpen" @update:open="handleRenameDialogOpenChange">
      <DialogContent :show-close-button="!isSavingDock">
        <DialogHeader>
          <DialogTitle>Ganti nama dock</DialogTitle>
          <DialogDescription>Perubahan nama langsung berlaku pada plant {{ plantLocation }}.</DialogDescription>
        </DialogHeader>
        <form class="space-y-4" @submit.prevent="renameDock">
          <div class="space-y-2">
            <Label for="rename-dock-name">Nama dock</Label>
            <Input id="rename-dock-name" v-model="renamedDockName" maxlength="120" required autofocus />
          </div>
          <p v-if="dialogError" role="alert" class="text-sm text-red-600 dark:text-red-400">
            {{ dialogError }}
          </p>
          <DialogFooter>
            <Button type="button" variant="outline" :disabled="isSavingDock" @click="handleRenameDialogOpenChange(false)">
              Batal
            </Button>
            <Button type="submit" :disabled="isSavingDock || !renamedDockName.trim()">
              <LoaderCircle v-if="isSavingDock" class="size-4 animate-spin" />
              {{ isSavingDock ? 'Menyimpan...' : 'Simpan perubahan' }}
            </Button>
          </DialogFooter>
        </form>
      </DialogContent>
    </Dialog>
  </div>
</template>
