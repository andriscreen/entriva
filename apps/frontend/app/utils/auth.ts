const dashboardPathByRole = {
  super_admin: '/dashboard/super-admin',
  admin_logistics: '/dashboard/admin-logistics',
  operator_logistics: '/dashboard/operator',
  admin_fs: '/dashboard/admin-fs',
  user_paragonian: '/dashboard/user',
  it_support: '/dashboard/it-support',
} as const

export type UserRole = keyof typeof dashboardPathByRole

const roleByDashboardSubpage: Record<string, UserRole> = {
  '/dashboard/operator/live-queue': 'operator_logistics',
  '/dashboard/operator/queue-history': 'operator_logistics',
  '/dashboard/operator/notifications': 'operator_logistics',
}

export function getDashboardPath(role: unknown): string | null {
  if (typeof role !== 'string' || !Object.prototype.hasOwnProperty.call(dashboardPathByRole, role)) {
    return null
  }

  return dashboardPathByRole[role as UserRole]
}

export function getDashboardRole(path: string): UserRole | null {
  for (const [role, dashboardPath] of Object.entries(dashboardPathByRole)) {
    if (dashboardPath === path) return role as UserRole
  }

  return roleByDashboardSubpage[path] ?? null
}
