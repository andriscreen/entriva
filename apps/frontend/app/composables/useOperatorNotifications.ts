export type OperatorNotification = {
  id: string
  queueId: string
  queueNumber: string
  licensePlate: string
  driverName: string
  checkedInAt: string | null
  isRead: boolean
}

export function useOperatorNotifications() {
  const notifications = useState<OperatorNotification[]>('operator-check-in-notifications', () => [])
  const notificationError = useState('operator-check-in-notification-error', () => '')
  const unreadCount = computed(() => notifications.value.filter(notification => !notification.isRead).length)

  function addCheckInNotification(notification: Omit<OperatorNotification, 'isRead'>) {
    if (notifications.value.some(existing => existing.queueId === notification.queueId)) return
    notifications.value = [{ ...notification, isRead: false }, ...notifications.value].slice(0, 50)
  }

  function markNotificationAsRead(id: string) {
    notifications.value = notifications.value.map(notification => (
      notification.id === id ? { ...notification, isRead: true } : notification
    ))
  }

  function markAllNotificationsAsRead() {
    notifications.value = notifications.value.map(notification => ({ ...notification, isRead: true }))
  }

  return {
    notifications,
    notificationError,
    unreadCount,
    addCheckInNotification,
    markNotificationAsRead,
    markAllNotificationsAsRead,
  }
}
