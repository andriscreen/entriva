import { createError, defineEventHandler } from 'h3'
import { getAdminSupabaseClient, requireAdminLogistics } from '../../utils/admin-logistics'

export default defineEventHandler(async (event) => {
  const { plantLocation } = await requireAdminLogistics(event)
  const supabase = getAdminSupabaseClient(event)
  const { data: operators, error } = await supabase
    .from('profiles')
    .select('id, email, full_name, phone_number, role, plant_location, created_at')
    .eq('role', 'operator_logistics')
    .eq('plant_location', plantLocation)
    .order('full_name', { ascending: true })

  if (error) {
    console.error('Unable to load logistics operators', error)
    throw createError({ statusCode: 500, statusMessage: 'Daftar operator gagal dimuat.' })
  }

  const operatorsWithStatus = await Promise.all((operators ?? []).map(async (operator) => {
    const { data, error: authError } = await supabase.auth.admin.getUserById(operator.id)

    if (authError) {
      console.error('Unable to load logistics operator auth status', authError)
      throw createError({ statusCode: 502, statusMessage: 'Status akun operator gagal dimuat.' })
    }

    const bannedUntil = data.user.banned_until ? Date.parse(data.user.banned_until) : 0
    return {
      ...operator,
      is_active: Number.isFinite(bannedUntil) && bannedUntil <= Date.now(),
    }
  }))

  return { plantLocation, operators: operatorsWithStatus }
})
