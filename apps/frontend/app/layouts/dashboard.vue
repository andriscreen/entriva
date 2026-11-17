<script setup lang="ts">
import {
  Bell,
  BookOpen,
  Building2,
  ChevronDown,
  CircleUserRound,
  Database,
  History,
  LayoutDashboard,
  LogOut,
  Map,
  Menu,
  MessageSquareMore,
  Moon,
  PanelLeftClose,
  PanelLeftOpen,
  ShieldCheck,
  Sun,
  Truck,
  Users,
  Wifi,
  X,
} from 'lucide-vue-next'
import { Avatar, AvatarFallback } from '@/components/ui/avatar'
import { Badge } from '@/components/ui/badge'
import { Button } from '@/components/ui/button'
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuLabel,
  DropdownMenuSeparator,
  DropdownMenuTrigger,
} from '@/components/ui/dropdown-menu'
import type { UserRole } from '@/utils/auth'

const route = useRoute()
const supabase = useSupabaseClient()
const supabaseUser = useSupabaseUser()
const authenticatedRole = useState<UserRole | null>('authenticated-user-role', () => null)
const accountAvatarPath = useState('account-avatar-path', () => '')
const { theme, toggleTheme } = useAppTheme()
const signOutError = ref('')
const isSidebarCollapsed = ref(false)
const isMobileSidebarOpen = ref(false)
const {
  notifications,
  notificationError,
  unreadCount,
  addCheckInNotification,
  markNotificationAsRead,
  markAllNotificationsAsRead,
} = useOperatorNotifications()
let queueNotificationChannel: ReturnType<typeof supabase.channel> | undefined
let knownWaitingQueueIds = new Set<string>()

const accountLabel = computed(() => {
  const fullName = supabaseUser.value?.user_metadata?.full_name
  return typeof fullName === 'string' && fullName.trim()
    ? fullName
    : supabaseUser.value?.email ?? 'Account'
})
const accountInitials = computed(() => accountLabel.value.slice(0, 2).toUpperCase())
const accountAvatar = computed(() => accountAvatarPath.value)

const roleKeyByPath = {
  '/dashboard/super-admin': 'super-admin-system',
  '/dashboard/admin-logistics': 'admin-logistics',
  '/dashboard/admin-logistics/docks': 'admin-logistics',
  '/dashboard/admin-logistics/history': 'admin-logistics',
  '/dashboard/admin-logistics/operators': 'admin-logistics',
  '/dashboard/admin-logistics/vendors': 'admin-logistics',
  '/dashboard/operator': 'operator-logistics',
  '/dashboard/admin-fs': 'admin-fs',
  '/dashboard/user': 'user-paragonian',
  '/dashboard/it-support': 'it-support',
  '/dashboard/operator/live-queue': 'operator-logistics',
  '/dashboard/operator/queue-history': 'operator-logistics',
  '/dashboard/operator/notifications': 'operator-logistics',
} as const

const roleKeyByUserRole: Record<UserRole, (typeof roleKeyByPath)[keyof typeof roleKeyByPath]> = {
  super_admin: 'super-admin-system',
  admin_logistics: 'admin-logistics',
  operator_logistics: 'operator-logistics',
  admin_fs: 'admin-fs',
  user_paragonian: 'user-paragonian',
  it_support: 'it-support',
}

const roleKey = computed(() => {
  const routeRole = roleKeyByPath[route.path as keyof typeof roleKeyByPath]
  if (routeRole) return routeRole

  return authenticatedRole.value
    ? roleKeyByUserRole[authenticatedRole.value]
    : 'super-admin-system'
})

const navItems = {
  'super-admin-system': [
    { label: 'Overview', icon: LayoutDashboard, href: '/dashboard/super-admin' },
    { label: 'Users', icon: Users, href: '/dashboard/super-admin?tab=users' },
    { label: 'Nodes', icon: Map, href: '/dashboard/super-admin?tab=nodes' },
    { label: 'Audit', icon: ShieldCheck, href: '/dashboard/super-admin?tab=audit' },
  ],
  'admin-logistics': [
    { label: 'Driver approval queue', icon: Truck, href: '/dashboard/admin-logistics' },
    { label: 'History', icon: History, href: '/dashboard/admin-logistics/history' },
    { label: 'Docking', icon: Map, href: '/dashboard/admin-logistics/docks' },
  ],
  'operator-logistics': [
    { label: 'Command Center', icon: LayoutDashboard, href: '/dashboard/operator' },
    { label: 'Digital Twin', icon: Map, href: '/dashboard/operator?tab=map' },
    { label: 'Notifications', icon: Bell, href: '/dashboard/operator/notifications' },
  ],
  'admin-fs': [
    { label: 'Visitors', icon: Users, href: '/dashboard/admin-fs' },
    { label: 'Mess Room', icon: LayoutDashboard, href: '/dashboard/admin-fs?tab=mess' },
    { label: 'Reports', icon: ShieldCheck, href: '/dashboard/admin-fs?tab=reports' },
  ],
  'user-paragonian': [
    { label: 'Invite', icon: Users, href: '/dashboard/user' },
    { label: 'Schedule', icon: Bell, href: '/dashboard/user?tab=schedule' },
  ],
  'it-support': [
    { label: 'OpenWA', icon: MessageSquareMore, href: '/dashboard/it-support' },
    { label: 'WiFi', icon: Wifi, href: '/dashboard/it-support?tab=wifi' },
    { label: 'Support', icon: ShieldCheck, href: '/dashboard/it-support?tab=support' },
  ],
} as const

const dataManagementItems = [
  { label: 'Akun operator', icon: Users, href: '/dashboard/admin-logistics/operators' },
  { label: 'Vendor', icon: Building2, href: '/dashboard/admin-logistics/vendors' },
] as const

const yardOperationsItems = [
  { label: 'Live vehicle queue', icon: Truck, href: '/dashboard/operator/live-queue' },
  { label: 'Queue History', icon: History, href: '/dashboard/operator/queue-history' },
] as const

const roleLabelMap = {
  'super-admin-system': 'Super Admin System',
  'admin-logistics': 'Admin Logistik',
  'operator-logistics': 'Operator Yard',
  'admin-fs': 'Admin FS / GA',
  'user-paragonian': 'User Paragonian',
  'it-support': 'IT Support',
} as const

const currentNav = computed(() => navItems[roleKey.value as keyof typeof navItems] ?? navItems['super-admin-system'])
const roleLabel = computed(() => roleLabelMap[roleKey.value as keyof typeof roleLabelMap] ?? 'Super Admin System')
const isDataManagementActive = computed(() => (
  roleKey.value === 'admin-logistics' && dataManagementItems.some(item => isActiveNavItem(item.href))
))
const isDataManagementOpen = ref(isDataManagementActive.value)
const isYardOperationsActive = computed(() => (
  roleKey.value === 'operator-logistics' && yardOperationsItems.some(item => isActiveNavItem(item.href))
))
const isYardOperationsOpen = ref(isYardOperationsActive.value)
const activeNavItem = computed(() => (
  currentNav.value.find(item => isActiveNavItem(item.href))
  ?? dataManagementItems.find(item => isActiveNavItem(item.href))
  ?? yardOperationsItems.find(item => isActiveNavItem(item.href))
  ?? currentNav.value[0]
))

watch(isDataManagementActive, (isActive) => {
  if (isActive) isDataManagementOpen.value = true
})

watch(isYardOperationsActive, (isActive) => {
  if (isActive) isYardOperationsOpen.value = true
})

function formatNotificationTime(value: string | null) {
  if (!value) return 'Time unavailable'
  const date = new Date(value)
  return Number.isNaN(date.getTime())
    ? 'Time unavailable'
    : new Intl.DateTimeFormat('id-ID', { dateStyle: 'short', timeStyle: 'short' }).format(date)
}

async function loadExistingWaitingQueueIds(plantLocation: string) {
  const queueIds = new Set<string>()
  const pageSize = 1000
  let offset = 0

  while (true) {
    const { data, error } = await supabase
      .from('logistics_queues')
      .select('id')
      .eq('plant_location', plantLocation)
      .eq('status', 'waiting_in_yard')
      .order('id', { ascending: true })
      .range(offset, offset + pageSize - 1)

    if (error) throw error

    const page = data ?? []
    for (const queue of page) queueIds.add(queue.id)
    if (page.length < pageSize) return queueIds
    offset += pageSize
  }
}

function handleQueueCheckIn(record: unknown) {
  if (typeof record !== 'object' || record === null) return
  const queue = record as Record<string, unknown>
  if (typeof queue.id !== 'string') return

  if (queue.status !== 'waiting_in_yard') {
    if (typeof queue.status === 'string') knownWaitingQueueIds.delete(queue.id)
    return
  }
  if (knownWaitingQueueIds.has(queue.id)) return

  knownWaitingQueueIds.add(queue.id)
  if (
    typeof queue.queue_number !== 'string'
    || typeof queue.license_plate !== 'string'
    || typeof queue.driver_name !== 'string'
  ) {
    console.error('New vehicle check-in notification is missing required queue details', record)
    notificationError.value = 'A check-in event arrived without complete vehicle details.'
    return
  }

  addCheckInNotification({
    id: queue.id,
    queueId: queue.id,
    queueNumber: queue.queue_number,
    licensePlate: queue.license_plate,
    driverName: queue.driver_name,
    checkedInAt: typeof queue.checked_in_at === 'string'
      ? queue.checked_in_at
      : typeof queue.updated_at === 'string'
        ? queue.updated_at
        : typeof queue.created_at === 'string'
          ? queue.created_at
          : null,
  })
}

async function startOperatorQueueNotifications() {
  if (roleKey.value !== 'operator-logistics' || queueNotificationChannel) return

  try {
    const { data: authData, error: authError } = await supabase.auth.getUser()
    if (authError) throw authError
    if (!authData.user) throw new Error('Your session could not be verified. Please sign in again.')

    const { data: profile, error: profileError } = await supabase
      .from('profiles')
      .select('plant_location')
      .eq('id', authData.user.id)
      .single()

    if (profileError) throw profileError
    if (typeof profile.plant_location !== 'string' || !profile.plant_location.trim()) {
      throw new Error('Plant location is missing from your profile. Contact an administrator.')
    }

    const plantLocation = profile.plant_location.trim()
    knownWaitingQueueIds = await loadExistingWaitingQueueIds(plantLocation)
    queueNotificationChannel = supabase.channel(`operator-check-in-notifications:${plantLocation}`)
    queueNotificationChannel
      .on('postgres_changes', {
        event: '*',
        schema: 'public',
        table: 'logistics_queues',
        filter: `plant_location=eq.${plantLocation}`,
      }, (payload) => {
        handleQueueCheckIn(payload.new)
      })
      .subscribe((status, error) => {
        if (status === 'SUBSCRIBED') {
          notificationError.value = ''
        } else if (status === 'CHANNEL_ERROR' || status === 'TIMED_OUT' || status === 'CLOSED') {
          notificationError.value = 'Live check-in notifications are offline.'
          if (status !== 'CLOSED') console.error('Operator check-in notification channel failed', error ?? status)
        }
      })
  } catch (error) {
    console.error('Unable to start operator check-in notifications', error)
    notificationError.value = error instanceof Error ? error.message : 'Unable to start live check-in notifications.'
  }
}

function openQueueNotification(id: string) {
  markNotificationAsRead(id)
  void navigateTo('/dashboard/operator/live-queue')
}

watch(() => route.fullPath, () => {
  isMobileSidebarOpen.value = false
  if (isDataManagementActive.value) isDataManagementOpen.value = true
  if (isYardOperationsActive.value) isYardOperationsOpen.value = true
})

function isActiveNavItem(href: string) {
  const [path] = href.split('?')
  if (route.path !== path) return false

  const tab = href.split('tab=')[1]
  return tab ? route.query.tab === tab : !route.query.tab
}

function toggleSidebar() {
  isSidebarCollapsed.value = !isSidebarCollapsed.value
}

function toggleDataManagement() {
  isDataManagementOpen.value = !isDataManagementOpen.value
}

function toggleYardOperations() {
  isYardOperationsOpen.value = !isYardOperationsOpen.value
}

async function handleSignOut() {
  signOutError.value = ''

  try {
    const { error } = await supabase.auth.signOut()
    if (error) {
      signOutError.value = error.message
      return
    }

    await navigateTo('/login')
  } catch (error) {
    console.error('Supabase sign out failed', error)
    signOutError.value = 'Tidak dapat keluar dari akun. Silakan coba lagi.'
  }
}

onMounted(startOperatorQueueNotifications)

onUnmounted(() => {
  if (queueNotificationChannel) void supabase.removeChannel(queueNotificationChannel)
})
</script>

<template>
  <div
    class="h-dvh overflow-hidden p-0 transition-colors duration-300 lg:p-6"
    :class="theme === 'dark' ? 'dark bg-[#090909] text-slate-100' : 'bg-slate-200 text-slate-900'"
  >
    <div
      class="relative mx-auto flex h-full min-h-0 max-w-[1600px] overflow-hidden transition-colors duration-300 lg:rounded-[2rem] lg:shadow-2xl"
      :class="theme === 'dark' ? 'bg-[#090909] lg:border lg:border-white/10' : 'bg-white lg:border lg:border-slate-300'"
    >
      <button
        v-if="isMobileSidebarOpen"
        type="button"
        class="fixed inset-0 z-40 bg-slate-950/60 backdrop-blur-sm lg:hidden"
        aria-label="Close navigation menu"
        @click="isMobileSidebarOpen = false"
      />

      <aside
        class="fixed inset-y-0 left-0 z-50 flex w-[272px] shrink-0 flex-col border-r border-white/[0.08] bg-[#171717] py-5 text-white shadow-2xl transition-all duration-300 lg:sticky lg:top-0 lg:h-full lg:shadow-none lg:translate-x-0"
        :class="[
          isSidebarCollapsed ? 'px-3 lg:w-[84px]' : 'px-4 lg:w-[272px]',
          isMobileSidebarOpen ? 'translate-x-0' : '-translate-x-full lg:translate-x-0',
        ]"
      >
        <div class="mb-8 flex h-12 items-center" :class="isSidebarCollapsed ? 'justify-center' : 'justify-between px-1'">
          <NuxtLink
            :to="currentNav[0].href"
            aria-label="Entriva workspace home"
            class="flex min-w-0 items-center gap-2"
            :class="isSidebarCollapsed ? 'lg:hidden' : ''"
            @click="isMobileSidebarOpen = false"
          >
            <img
              src="/img/entrivaputih.png"
              alt=""
              class="h-9 w-9 shrink-0 object-contain"
            />
            <span
              class="text-xl font-bold tracking-[0.12em]"
              :class="isSidebarCollapsed ? 'hidden lg:inline' : ''"
            >
              Entriva
            </span>
          </NuxtLink>
          <Button
            variant="ghost"
            size="icon"
            class="hidden size-9 shrink-0 rounded-lg text-slate-400 hover:bg-white/[0.08] hover:text-white lg:inline-flex"
            :aria-label="isSidebarCollapsed ? 'Expand sidebar' : 'Minimize sidebar'"
            :title="isSidebarCollapsed ? 'Expand sidebar' : 'Minimize sidebar'"
            @click="toggleSidebar"
          >
            <PanelLeftOpen v-if="isSidebarCollapsed" class="size-4" />
            <PanelLeftClose v-else class="size-4" />
          </Button>
          <Button
            variant="ghost"
            size="icon"
            class="size-9 shrink-0 rounded-lg text-slate-400 hover:bg-white/[0.08] hover:text-white lg:hidden"
            aria-label="Close navigation menu"
            @click="isMobileSidebarOpen = false"
          >
            <X class="size-4" />
          </Button>
        </div>

        <div
          class="mb-3 px-3 text-[11px] font-semibold uppercase tracking-[0.18em] text-slate-500"
          :class="isSidebarCollapsed ? 'lg:hidden' : ''"
        >
          Workspace
        </div>
        <nav class="flex-1 space-y-1" aria-label="Dashboard navigation">
          <Button
            v-for="item in currentNav"
            :key="item.label"
            as-child
            variant="ghost"
            class="h-11 w-full rounded-xl text-sm transition-colors duration-300"
            :class="[
              isSidebarCollapsed ? 'justify-center px-0 lg:justify-center' : 'justify-start gap-3 px-3',
              isActiveNavItem(item.href)
                ? 'bg-[#FACC15] text-[#090909] shadow-sm hover:bg-[#FDE68A] hover:text-[#090909]'
                : 'text-slate-300 hover:bg-white/[0.07] hover:text-white',
            ]"
            :title="isSidebarCollapsed ? item.label : undefined"
          >
            <NuxtLink :to="item.href" class="flex items-center" :class="isSidebarCollapsed ? 'justify-center' : 'gap-3'" @click="isMobileSidebarOpen = false">
              <component :is="item.icon" class="size-[18px]" />
              <span
                class="min-w-0 max-w-48 overflow-hidden whitespace-nowrap transition-all duration-300 ease-out motion-reduce:transition-none"
                :class="isSidebarCollapsed
                  ? 'lg:max-w-0 lg:translate-x-1 lg:opacity-0'
                  : 'lg:max-w-48 lg:translate-x-0 lg:opacity-100'"
              >
                {{ item.label }}
              </span>
              <Badge
                v-if="item.label === 'Notifications' && unreadCount > 0 && !isSidebarCollapsed"
                variant="secondary"
                class="ml-auto h-5 min-w-5 justify-center px-1 text-[10px]"
              >
                {{ unreadCount > 9 ? '9+' : unreadCount }}
              </Badge>
            </NuxtLink>
          </Button>
          <div v-if="roleKey === 'admin-logistics'" class="mt-1">
            <Button
              type="button"
              variant="ghost"
              class="h-11 w-full rounded-xl text-sm transition-colors duration-300"
              :class="[
                isSidebarCollapsed ? 'justify-center px-0 lg:justify-center' : 'justify-start gap-3 px-3',
                isDataManagementActive
                  ? 'bg-[#FACC15] text-[#090909] shadow-sm hover:bg-[#FDE68A] hover:text-[#090909]'
                  : 'text-slate-300 hover:bg-white/[0.07] hover:text-white',
              ]"
              :title="isSidebarCollapsed ? 'Manajemen Data' : undefined"
              :aria-expanded="isDataManagementOpen"
              aria-controls="admin-logistics-data-management"
              @click="toggleDataManagement"
            >
              <span class="flex min-w-0 items-center" :class="isSidebarCollapsed ? 'justify-center' : 'gap-3'">
                <Database class="size-[18px] shrink-0" />
                <span
                  class="min-w-0 max-w-48 overflow-hidden whitespace-nowrap transition-all duration-300 ease-out motion-reduce:transition-none"
                  :class="isSidebarCollapsed
                    ? 'lg:max-w-0 lg:translate-x-1 lg:opacity-0'
                    : 'lg:max-w-48 lg:translate-x-0 lg:opacity-100'"
                >
                  Manajemen Data
                </span>
                <ChevronDown
                  v-if="!isSidebarCollapsed"
                  class="ml-auto size-4 shrink-0 transition-transform duration-200"
                  :class="isDataManagementOpen ? 'rotate-180' : ''"
                />
              </span>
            </Button>
            <div
              v-if="isDataManagementOpen"
              id="admin-logistics-data-management"
              class="mt-1 space-y-1"
            >
              <Button
                v-for="item in dataManagementItems"
                :key="item.href"
                as-child
                variant="ghost"
                class="h-10 w-full rounded-xl text-sm transition-colors duration-300"
                :class="[
                  isSidebarCollapsed
                    ? 'justify-center px-0 lg:justify-center'
                    : 'ml-2 w-[calc(100%-0.5rem)] justify-start gap-3 px-3',
                  isActiveNavItem(item.href)
                    ? 'bg-[#FACC15] text-[#090909] shadow-sm hover:bg-[#FDE68A] hover:text-[#090909]'
                    : 'text-slate-300 hover:bg-white/[0.07] hover:text-white',
                ]"
                :title="isSidebarCollapsed ? item.label : undefined"
              >
                <NuxtLink
                  :to="item.href"
                  class="flex items-center"
                  :class="isSidebarCollapsed ? 'justify-center' : 'gap-3'"
                  @click="isMobileSidebarOpen = false"
                >
                  <component :is="item.icon" class="size-[18px]" />
                  <span
                    class="min-w-0 max-w-48 overflow-hidden whitespace-nowrap transition-all duration-300 ease-out motion-reduce:transition-none"
                    :class="isSidebarCollapsed
                      ? 'lg:max-w-0 lg:translate-x-1 lg:opacity-0'
                      : 'lg:max-w-48 lg:translate-x-0 lg:opacity-100'"
                  >
                    {{ item.label }}
                  </span>
                </NuxtLink>
              </Button>
            </div>
          </div>
          <div v-if="roleKey === 'operator-logistics'" class="mt-1">
            <Button
              type="button"
              variant="ghost"
              class="h-11 w-full rounded-xl text-sm transition-colors duration-300"
              :class="[
                isSidebarCollapsed ? 'justify-center px-0 lg:justify-center' : 'justify-start gap-3 px-3',
                isYardOperationsActive
                  ? 'bg-[#FACC15] text-[#090909] shadow-sm hover:bg-[#FDE68A] hover:text-[#090909]'
                  : 'text-slate-300 hover:bg-white/[0.07] hover:text-white',
              ]"
              :title="isSidebarCollapsed ? 'Yard Operations' : undefined"
              :aria-expanded="isYardOperationsOpen"
              aria-controls="operator-yard-operations"
              @click="toggleYardOperations"
            >
              <span class="flex min-w-0 items-center" :class="isSidebarCollapsed ? 'justify-center' : 'gap-3'">
                <Truck class="size-[18px] shrink-0" />
                <span
                  class="min-w-0 max-w-48 overflow-hidden whitespace-nowrap transition-all duration-300 ease-out motion-reduce:transition-none"
                  :class="isSidebarCollapsed
                    ? 'lg:max-w-0 lg:translate-x-1 lg:opacity-0'
                    : 'lg:max-w-48 lg:translate-x-0 lg:opacity-100'"
                >
                  Yard Operations
                </span>
                <ChevronDown
                  v-if="!isSidebarCollapsed"
                  class="ml-auto size-4 shrink-0 transition-transform duration-200"
                  :class="isYardOperationsOpen ? 'rotate-180' : ''"
                />
              </span>
            </Button>
            <div
              v-if="isYardOperationsOpen"
              id="operator-yard-operations"
              class="mt-1 space-y-1"
            >
              <Button
                v-for="item in yardOperationsItems"
                :key="item.href"
                as-child
                variant="ghost"
                class="h-10 w-full rounded-xl text-sm transition-colors duration-300"
                :class="[
                  isSidebarCollapsed
                    ? 'justify-center px-0 lg:justify-center'
                    : 'ml-2 w-[calc(100%-0.5rem)] justify-start gap-3 px-3',
                  isActiveNavItem(item.href)
                    ? 'bg-[#FACC15] text-[#090909] shadow-sm hover:bg-[#FDE68A] hover:text-[#090909]'
                    : 'text-slate-300 hover:bg-white/[0.07] hover:text-white',
                ]"
                :title="isSidebarCollapsed ? item.label : undefined"
              >
                <NuxtLink
                  :to="item.href"
                  class="flex items-center"
                  :class="isSidebarCollapsed ? 'justify-center' : 'gap-3'"
                  @click="isMobileSidebarOpen = false"
                >
                  <component :is="item.icon" class="size-[18px]" />
                  <span
                    class="min-w-0 max-w-48 overflow-hidden whitespace-nowrap transition-all duration-300 ease-out motion-reduce:transition-none"
                    :class="isSidebarCollapsed
                      ? 'lg:max-w-0 lg:translate-x-1 lg:opacity-0'
                      : 'lg:max-w-48 lg:translate-x-0 lg:opacity-100'"
                  >
                    {{ item.label }}
                  </span>
                </NuxtLink>
              </Button>
            </div>
          </div>
        </nav>

        <div
          class="mb-4 rounded-xl border border-slate-200 bg-white p-3"
          :class="isSidebarCollapsed ? 'lg:hidden' : ''"
        >
          <div class="flex items-center gap-2.5">
            <span class="flex size-8 shrink-0 items-center justify-center rounded-lg  text-[#171717]">
              <BookOpen class="size-4" />
            </span>
            <div class="min-w-0">
              <h2 class="truncate text-xs font-semibold text-[#171717]">Guide Books</h2>
            </div>
          </div>
        </div>

      </aside>

      <main class="flex h-full min-h-0 min-w-0 flex-1 flex-col">
        <header
          class="z-30 shrink-0 border-b px-4 py-4 sm:px-6 sm:py-5 lg:px-8"
          :class="theme === 'dark' ? 'border-white/[0.08] bg-[#171717]' : 'border-slate-100 bg-transparent'"
        >
          <div class="flex items-center justify-between gap-4">
            <div class="min-w-0 flex-1">
              <div class="flex items-center gap-3 lg:hidden">
                <Button
                  variant="ghost"
                  size="icon"
                  class="size-9 shrink-0 rounded-xl"
                  :class="theme === 'dark' ? 'bg-white/[0.04] text-slate-300 hover:bg-white/[0.08]' : 'text-slate-600 hover:bg-slate-100'"
                  aria-label="Open navigation menu"
                  @click="isMobileSidebarOpen = true"
                >
                  <Menu class="size-4" />
                </Button>
                <NuxtLink :to="currentNav[0].href" aria-label="Entriva workspace home" class="flex min-w-0 items-center gap-2">
                  <img
                    :src="theme === 'dark' ? '/img/entrivaputih.png' : '/img/entrivaputih.png'"
                    alt=""
                    class="h-8 w-8 shrink-0 object-contain"
                  />
                  <span
                    class="truncate text-base font-bold tracking-[0.12em]"
                    :class="theme === 'dark' ? 'text-white' : 'text-slate-950'"
                  >
                    Entriva
                  </span>
                </NuxtLink>
              </div>

              <div class="hidden min-w-0 lg:block">
                <p class="text-xs font-medium text-slate-500 dark:text-slate-400">{{ activeNavItem.label }} · {{ roleLabel }}</p>
                <h1 class="mt-1 truncate text-xl font-semibold tracking-tight sm:text-2xl" :class="theme === 'dark' ? 'text-white' : 'text-[#171717]'">
                  Welcome back, {{ accountLabel }}!
                </h1>
              </div>
            </div>

            <div class="ml-auto flex items-center gap-2 lg:ml-0">

              <DropdownMenu>
                <DropdownMenuTrigger as-child>
                  <Button
                    variant="ghost"
                    size="icon"
                    class="relative size-9 rounded-xl"
                    :class="theme === 'dark' ? 'text-slate-300 hover:bg-white/[0.08]' : 'text-slate-600 hover:bg-slate-100'"
                    :aria-label="unreadCount ? `Notifications, ${unreadCount} unread` : 'Notifications'"
                    title="Notifications"
                  >
                    <Bell class="size-[18px]" />
                    <span
                      v-if="unreadCount > 0"
                      class="absolute -right-1 -top-1 flex h-5 min-w-5 items-center justify-center rounded-full bg-[#FACC15] px-1 text-[10px] font-semibold text-[#171717]"
                    >
                      {{ unreadCount > 9 ? '9+' : unreadCount }}
                    </span>
                  </Button>
                </DropdownMenuTrigger>
                <DropdownMenuContent
                  align="end"
                  class="w-80 max-h-[min(70vh,28rem)] overflow-y-auto"
                  :class="theme === 'dark' ? 'border-white/10 bg-[#11182a] text-slate-100' : 'border-slate-200 bg-white text-slate-900'"
                >
                  <DropdownMenuLabel>Notifications</DropdownMenuLabel>
                  <DropdownMenuItem v-if="unreadCount > 0" class="justify-end" @select="markAllNotificationsAsRead">
                    Mark all as read
                  </DropdownMenuItem>
                  <DropdownMenuSeparator :class="theme === 'dark' ? 'bg-white/10' : 'bg-slate-100'" />
                  <p v-if="notificationError" role="alert" class="px-2 py-2 text-xs text-red-500">
                    {{ notificationError }}
                  </p>
                  <p v-else-if="notifications.length === 0" class="px-2 py-4 text-center text-sm text-muted-foreground">
                    No vehicle check-ins yet.
                  </p>
                  <DropdownMenuItem
                    v-for="notification in notifications"
                    :key="notification.id"
                    class="cursor-pointer items-start whitespace-normal py-3"
                    :class="!notification.isRead ? 'bg-muted/50' : ''"
                    @select="openQueueNotification(notification.id)"
                  >
                    <div class="flex w-full flex-col gap-1">
                      <div class="flex items-center justify-between gap-2">
                        <Badge variant="outline">New check-in</Badge>
                        <span v-if="!notification.isRead" class="size-2 rounded-full bg-[#FACC15]" />
                      </div>
                      <span class="font-medium">{{ notification.licensePlate }} · {{ notification.driverName }}</span>
                      <span class="text-xs text-muted-foreground">{{ notification.queueNumber }} · {{ formatNotificationTime(notification.checkedInAt) }}</span>
                    </div>
                  </DropdownMenuItem>
                </DropdownMenuContent>
              </DropdownMenu>

              <Button
                variant="ghost"
                size="icon"
                class="size-9 rounded-xl"
                :class="theme === 'dark'
                  ? 'bg-white/[0.03] text-[#FDE68A] hover:bg-white/[0.08] hover:text-[#FACC15]'
                  : 'bg-white text-slate-600 hover:bg-slate-100 hover:text-slate-950'"
                :aria-label="theme === 'dark' ? 'Switch to light mode' : 'Switch to dark mode'"
                :title="theme === 'dark' ? 'Light mode' : 'Dark mode'"
                @click="toggleTheme"
              >
                <Sun v-if="theme === 'dark'" class="size-4" />
                <Moon v-else class="size-4" />
              </Button>

              <DropdownMenu>
                <DropdownMenuTrigger as-child>
                  <Button
                    variant="ghost"
                    class="h-auto gap-2 rounded-xl border px-2 py-1.5 sm:px-3"
                    :class="theme === 'dark'
                      ? 'border-white/[0.07] bg-white/[0.03] hover:bg-white/[0.07]'
                      : 'border-slate-200 bg-white hover:bg-slate-100'"
                  >
                    <Avatar class="size-8 border border-[#FACC15]/40 bg-[#FACC15]/20">
                      <img
                        v-if="accountAvatar"
                        :src="accountAvatar"
                        :alt="accountLabel"
                        loading="eager"
                        fetchpriority="high"
                        class="size-full rounded-full object-cover"
                        @error="accountAvatarPath = ''"
                      >
                      <AvatarFallback v-else class="bg-[#FACC15]/20 text-[11px] font-semibold text-[#171717] dark:bg-[#FACC15]/15 dark:text-[#FDE68A]">
                        {{ accountInitials }}
                      </AvatarFallback>
                    </Avatar>
                    <span class="hidden min-w-0 text-left sm:block">
                      <span class="block max-w-36 truncate text-xs font-semibold" :class="theme === 'dark' ? 'text-white' : 'text-slate-900'">{{ accountLabel }}</span>
                      <span class="mt-0.5 block text-[10px] text-slate-500">{{ roleLabel }}</span>
                    </span>
                    <ChevronDown class="hidden size-4 text-slate-500 sm:block" />
                  </Button>
                </DropdownMenuTrigger>
                <DropdownMenuContent
                  align="end"
                  class="w-60"
                  :class="theme === 'dark' ? 'border-white/10 bg-[#11182a] text-slate-100' : 'border-slate-200 bg-white text-slate-900'"
                >
                  <DropdownMenuItem as-child>
                    <NuxtLink to="/account/editprofile" class="cursor-pointer">
                      <CircleUserRound class="mr-2 size-4" />
                      Edit profile
                    </NuxtLink>
                  </DropdownMenuItem>
                  <DropdownMenuSeparator :class="theme === 'dark' ? 'bg-white/10' : 'bg-slate-100'" />
                  <DropdownMenuItem
                    class="cursor-pointer"
                    :class="theme === 'dark' ? 'focus:bg-white/[0.08] focus:text-white' : 'focus:bg-slate-100 focus:text-slate-950'"
                    @select="handleSignOut"
                  >
                    <LogOut class="mr-2 size-4" />
                    Sign out
                  </DropdownMenuItem>
                </DropdownMenuContent>
              </DropdownMenu>
            </div>
          </div>
          <div class="mt-5 lg:hidden">
            <p class="text-xs font-medium text-slate-500 dark:text-slate-400">{{ activeNavItem.label }} · {{ roleLabel }}</p>
            <h1 class="mt-1 text-xl font-semibold tracking-tight sm:text-2xl" :class="theme === 'dark' ? 'text-white' : 'text-[#171717]'">
              Welcome back, {{ accountLabel }}!
            </h1>
          </div>
        </header>

        <div class="min-h-0 flex-1 overflow-y-auto overscroll-contain p-4 sm:p-6 lg:p-8">
          <p
            v-if="signOutError"
            role="alert"
            class="mb-5 rounded-xl border px-4 py-3 text-sm"
            :class="theme === 'dark' ? 'border-red-500/20 bg-red-500/10 text-red-300' : 'border-red-200 bg-red-50 text-red-700'"
          >
            {{ signOutError }}
          </p>
          <slot />
        </div>
      </main>
    </div>
  </div>
</template>
