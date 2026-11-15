<script setup lang="ts">
import { CircleCheck } from 'lucide-vue-next'
import { Button } from '@/components/ui/button'
import {
  Dialog,
  DialogClose,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from '@/components/ui/dialog'

const { message, closeSuccess } = useSuccessModal()
const isOpen = computed(() => Boolean(message.value))

function handleOpenChange(open: boolean) {
  if (!open) closeSuccess()
}
</script>

<template>
  <Dialog :open="isOpen" @update:open="handleOpenChange">
    <DialogContent :show-close-button="false" class="gap-6 p-6 sm:max-w-md">
      <DialogHeader class="items-center text-center">
        <div class="flex size-14 items-center justify-center rounded-full bg-emerald-500/10 text-emerald-600 dark:text-emerald-400">
          <CircleCheck class="size-8" aria-hidden="true" />
        </div>
        <DialogTitle class="text-xl">Berhasil</DialogTitle>
        <DialogDescription>{{ message }}</DialogDescription>
      </DialogHeader>
      <DialogFooter class="sm:justify-center">
        <DialogClose as-child>
          <Button class="min-w-28">Tutup</Button>
        </DialogClose>
      </DialogFooter>
    </DialogContent>
  </Dialog>
</template>
