import { getDashboardPath, getDashboardRole, type UserRole } from '@/utils/auth'

export default defineNuxtRouteMiddleware(async (to) => {
  const isDashboardRoute = to.path === '/dashboard' || to.path.startsWith('/dashboard/')
  const isAccountRoute = to.path === '/account' || to.path.startsWith('/account/')
  if (!isDashboardRoute && !isAccountRoute) return

  const supabase = useSupabaseClient()
  const { data: sessionData, error: sessionError } = await supabase.auth.getSession()

  if (sessionError) {
    return navigateTo({ path: '/login', query: { error: 'session' } })
  }

  if (!sessionData.session) {
    return navigateTo('/login')
  }

  const { data: userData, error: userError } = await supabase.auth.getUser()
  if (userError || !userData.user) {
    return navigateTo({ path: '/login', query: { error: 'session' } })
  }

  const { data: profile, error: profileError } = await supabase
    .from('profiles')
    .select('role, avatar_path')
    .eq('id', userData.user.id)
    .single()

  if (profileError) {
    return navigateTo({ path: '/login', query: { error: 'profile' } })
  }

  const dashboardPath = getDashboardPath(profile.role)
  if (!dashboardPath) {
    return navigateTo({ path: '/login', query: { error: 'role' } })
  }

  const authenticatedRole = getDashboardRole(dashboardPath)
  if (!authenticatedRole) {
    return navigateTo({ path: '/login', query: { error: 'role' } })
  }

  useState<UserRole | null>('authenticated-user-role', () => null).value = authenticatedRole
  useState<string>('account-avatar-path', () => '').value =
    typeof profile.avatar_path === 'string'
      && /^\/avatar\/avatar(?:[1-9]|1[0-8])\.jpg$/.test(profile.avatar_path)
      ? profile.avatar_path
      : ''

  if (isAccountRoute) return

  const routeRole = getDashboardRole(to.path)
  if ((routeRole && routeRole !== profile.role) || (!routeRole && to.path !== dashboardPath)) {
    return navigateTo(dashboardPath)
  }
})
