<script setup lang="ts">
import { Bell, CheckCheck } from 'lucide-vue-next'
import { Badge } from '@/components/ui/badge'
import { Button } from '@/components/ui/button'
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card'

definePageMeta({ layout: 'dashboard' })

const {
  notifications,
  notificationError,
  unreadCount,
  markNotificationAsRead,
  markAllNotificationsAsRead,
} = useOperatorNotifications()

function formatNotificationTime(value: string | null) {
  if (!value) return 'Time unavailable'
  const date = new Date(value)
  return Number.isNaN(date.getTime())
    ? 'Time unavailable'
    : new Intl.DateTimeFormat('id-ID', { dateStyle: 'medium', timeStyle: 'short' }).format(date)
}
</script>

<template>
  <div class="space-y-6">
    <div>
      <p class="text-sm text-muted-foreground">Yard Operations</p>
      <h1 class="text-3xl font-semibold tracking-tight">Notifications</h1>
    </div>

    <Card>
      <CardHeader class="flex-row items-start justify-between gap-4">
        <div>
          <CardTitle class="flex items-center gap-2"><Bell class="size-5" /> Vehicle check-ins</CardTitle>
          <CardDescription class="mt-1">Notifications appear when a vehicle enters the yard queue.</CardDescription>
        </div>
        <div class="flex shrink-0 items-center gap-2">
          <Badge variant="secondary">{{ unreadCount }} unread</Badge>
          <Button
            variant="outline"
            size="sm"
            :disabled="unreadCount === 0"
            @click="markAllNotificationsAsRead"
          >
            <CheckCheck class="size-4" />
            Mark all read
          </Button>
        </div>
      </CardHeader>
      <CardContent class="space-y-3">
        <p v-if="notificationError" role="alert" class="rounded-lg border border-red-500/20 bg-red-500/10 px-4 py-3 text-sm text-red-500">
          {{ notificationError }}
        </p>
        <p v-else-if="notifications.length === 0" class="py-10 text-center text-sm text-muted-foreground">
          No vehicle check-ins yet. New check-ins will appear here while you are signed in.
        </p>
        <NuxtLink
          v-for="notification in notifications"
          :key="notification.id"
          to="/dashboard/operator/live-queue"
          class="block rounded-lg border p-4 transition-colors hover:bg-muted/40"
          :class="notification.isRead ? 'bg-card' : 'border-primary/40 bg-muted/20'"
          @click="markNotificationAsRead(notification.id)"
        >
          <div class="flex flex-wrap items-start justify-between gap-3">
            <div class="flex items-start gap-3">
              <span class="mt-1 flex size-8 shrink-0 items-center justify-center rounded-full bg-primary/10 text-primary">
                <Bell class="size-4" />
              </span>
              <div>
                <p class="font-medium">Vehicle checked in: {{ notification.licensePlate }}</p>
                <p class="mt-1 text-sm text-muted-foreground">
                  {{ notification.driverName }} · {{ notification.queueNumber }}
                </p>
                <p class="mt-2 text-xs text-muted-foreground">
                  {{ formatNotificationTime(notification.checkedInAt) }}
                </p>
              </div>
            </div>
            <Badge :variant="notification.isRead ? 'outline' : 'secondary'">
              {{ notification.isRead ? 'Read' : 'New' }}
            </Badge>
          </div>
        </NuxtLink>
      </CardContent>
    </Card>
  </div>
</template>
