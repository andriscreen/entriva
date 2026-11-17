<script setup lang="ts">
import { ArrowRightLeft, Clock3, LoaderCircle } from 'lucide-vue-next'
import { Badge } from '@/components/ui/badge'
import { Button } from '@/components/ui/button'
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from '@/components/ui/dialog'
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from '@/components/ui/select'

type QueueTransferSubject = {
  id: string
  queue_number: string
  license_plate: string
}
type TransferRecord = {
  id: string
  source_plant: string
  target_plant: string
  transferred_by_name: string
  transferred_at: string
}
type TransferResult = {
  queue_number: string
  source_plant: string
  target_plant: string
  transferred_by_name: string
}

const plantOptions = ['Jatake 1', 'Jatake 2', 'Jatake 3', 'Jatake 6']
const props = defineProps<{
  queue: QueueTransferSubject
  sourcePlant: string
  disabled?: boolean
}>()
const emit = defineEmits<{
  transferred: []
}>()

const supabase = useSupabaseClient()
const { showSuccess } = useSuccessModal()
const isOpen = ref(false)
const targetPlant = ref('')
const transferHistory = ref<TransferRecord[]>([])
const isLoadingHistory = ref(false)
const isTransferring = ref(false)
const transferError = ref('')
const historyError = ref('')

const availablePlants = computed(() => plantOptions.filter(plant => plant !== props.sourcePlant))

function getErrorMessage(error: unknown) {
  if (error instanceof Error) return error.message
  if (typeof error === 'object' && error !== null && 'message' in error && typeof error.message === 'string') {
    return error.message
  }
  return 'Alih plant gagal diproses.'
}

function isTransferResult(value: unknown): value is TransferResult {
  return typeof value === 'object'
    && value !== null
    && 'queue_number' in value
    && typeof value.queue_number === 'string'
    && 'source_plant' in value
    && typeof value.source_plant === 'string'
    && 'target_plant' in value
    && typeof value.target_plant === 'string'
    && 'transferred_by_name' in value
    && typeof value.transferred_by_name === 'string'
}

function formatTransferTime(value: string) {
  const date = new Date(value)
  if (Number.isNaN(date.getTime())) return 'Waktu tidak tersedia'

  return new Intl.DateTimeFormat('id-ID', {
    dateStyle: 'medium',
    timeStyle: 'short',
    timeZone: 'Asia/Jakarta',
  }).format(date)
}

async function loadTransferHistory() {
  isLoadingHistory.value = true
  historyError.value = ''

  try {
    const { data, error } = await supabase
      .from('logistics_queue_transfers')
      .select('id, source_plant, target_plant, transferred_by_name, transferred_at')
      .eq('queue_id', props.queue.id)
      .order('transferred_at', { ascending: false })
      .limit(10)

    if (error) throw error
    transferHistory.value = data ?? []
  } catch (error) {
    console.error('Unable to load logistics queue plant transfer history', error)
    historyError.value = getErrorMessage(error)
  } finally {
    isLoadingHistory.value = false
  }
}

async function handleOpenChange(open: boolean) {
  isOpen.value = open
  transferError.value = ''

  if (open) {
    targetPlant.value = ''
    await loadTransferHistory()
  }
}

async function transferQueue() {
  if (!targetPlant.value || isTransferring.value || props.disabled) return

  isTransferring.value = true
  transferError.value = ''

  try {
    const { data, error } = await supabase.rpc('transfer_logistics_queue_plant', {
      p_queue_id: props.queue.id,
      p_target_plant: targetPlant.value,
    })

    if (error) throw error
    const result = Array.isArray(data) ? data[0] : data
    if (!isTransferResult(result)) {
      throw new Error('Respons alih plant dari server tidak valid.')
    }

    isOpen.value = false
    showSuccess(
      `${result.queue_number} dialihkan dari ${result.source_plant} ke ${result.target_plant} oleh ${result.transferred_by_name}. Waktu check-in tetap dipakai untuk FIFO.`,
    )
    emit('transferred')
  } catch (error) {
    console.error('Unable to transfer logistics queue plant', error)
    transferError.value = getErrorMessage(error)
  } finally {
    isTransferring.value = false
  }
}
</script>

<template>
  <div>
    <Button
      size="sm"
      variant="outline"
      :disabled="disabled"
      @click="handleOpenChange(true)"
    >
      <ArrowRightLeft class="size-4" />
      Alih plant
    </Button>

    <Dialog :open="isOpen" @update:open="handleOpenChange">
      <DialogContent class="max-h-[90vh] overflow-y-auto sm:max-w-lg">
        <DialogHeader>
          <DialogTitle>Alih plant kendaraan</DialogTitle>
          <DialogDescription>
            {{ queue.license_plate }} · {{ queue.queue_number }}. Fitur ini hanya berlaku saat kendaraan menunggu di yard.
          </DialogDescription>
        </DialogHeader>

        <div class="space-y-4">
          <div class="rounded-lg border bg-muted/30 p-3 text-sm">
            <p><span class="text-muted-foreground">Dari:</span> {{ sourcePlant }}</p>
            <p class="mt-1"><span class="text-muted-foreground">Check-in:</span> waktu awal tetap dipakai untuk urutan FIFO.</p>
          </div>

          <div class="space-y-2">
            <label class="text-sm font-medium" for="transfer-target-plant">Plant tujuan</label>
            <Select v-model="targetPlant">
              <SelectTrigger id="transfer-target-plant" aria-label="Pilih plant tujuan">
                <SelectValue placeholder="Pilih plant tujuan" />
              </SelectTrigger>
              <SelectContent>
                <SelectItem v-for="plant in availablePlants" :key="plant" :value="plant">
                  {{ plant }}
                </SelectItem>
              </SelectContent>
            </Select>
          </div>

          <div class="space-y-2 rounded-lg border p-3">
            <div class="flex items-center justify-between gap-2">
              <p class="text-sm font-medium">Riwayat alih plant</p>
              <Badge variant="secondary">{{ transferHistory.length }}</Badge>
            </div>
            <p v-if="isLoadingHistory" class="text-sm text-muted-foreground">
              <LoaderCircle class="mr-1 inline size-4 animate-spin" />
              Memuat riwayat...
            </p>
            <p v-else-if="historyError" role="alert" class="text-sm text-red-600">
              {{ historyError }}
            </p>
            <p v-else-if="transferHistory.length === 0" class="text-sm text-muted-foreground">
              Belum pernah dialihkan.
            </p>
            <ol v-else class="space-y-3">
              <li v-for="transfer in transferHistory" :key="transfer.id" class="border-t pt-3 first:border-t-0 first:pt-0">
                <p class="text-sm font-medium">
                  {{ transfer.source_plant }} → {{ transfer.target_plant }}
                </p>
                <p class="mt-1 flex flex-wrap items-center gap-x-2 text-xs text-muted-foreground">
                  <span>{{ transfer.transferred_by_name }}</span>
                  <span aria-hidden="true">·</span>
                  <span><Clock3 class="mr-1 inline size-3" />{{ formatTransferTime(transfer.transferred_at) }} WIB</span>
                </p>
              </li>
            </ol>
          </div>

          <p v-if="transferError" role="alert" class="rounded-lg border border-red-500/20 bg-red-500/10 px-3 py-2 text-sm text-red-700">
            {{ transferError }}
          </p>
        </div>

        <DialogFooter>
          <Button variant="outline" :disabled="isTransferring" @click="handleOpenChange(false)">
            Batal
          </Button>
          <Button :disabled="!targetPlant || isTransferring || disabled" @click="transferQueue">
            <LoaderCircle v-if="isTransferring" class="size-4 animate-spin" />
            <ArrowRightLeft v-else class="size-4" />
            {{ isTransferring ? 'Mengalihkan...' : 'Konfirmasi alih plant' }}
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  </div>
</template>
