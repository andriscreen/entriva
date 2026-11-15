import type { H3Event } from 'h3'
import { createError, getRouterParam } from 'h3'
import { serverSupabaseClient, serverSupabaseServiceRole } from '#supabase/server'

export async function requireAdminLogistics(event: H3Event) {
  const supabase = await serverSupabaseClient(event)
  const { data: authData, error: authError } = await supabase.auth.getUser()

  if (authError || !authData.user) {
    throw createError({
      statusCode: 401,
      statusMessage: 'Sesi pengguna tidak valid. Silakan masuk kembali.',
    })
  }

  const { data: profile, error: profileError } = await supabase
    .from('profiles')
    .select('role, plant_location')
    .eq('id', authData.user.id)
    .single()

  if (profileError) {
    console.error('Unable to verify admin logistics profile', profileError)
    throw createError({
      statusCode: 500,
      statusMessage: 'Profil admin gagal diverifikasi.',
    })
  }

  if (profile.role !== 'admin_logistics') {
    throw createError({
      statusCode: 403,
      statusMessage: 'Akses hanya tersedia untuk admin logistik.',
    })
  }

  if (typeof profile.plant_location !== 'string' || !profile.plant_location.trim()) {
    throw createError({
      statusCode: 403,
      statusMessage: 'Plant admin logistik tidak ditemukan.',
    })
  }

  return {
    user: authData.user,
    plantLocation: profile.plant_location.trim(),
  }
}

export function getAdminSupabaseClient(event: H3Event) {
  try {
    return serverSupabaseServiceRole(event)
  } catch (error) {
    console.error('Supabase server key is unavailable for admin logistics mutations', error)
    throw createError({
      statusCode: 503,
      statusMessage: 'Fitur ini belum dikonfigurasi. Atur secret key Supabase di environment server.',
    })
  }
}

export async function requireLogisticsOperator(event: H3Event) {
  const { plantLocation } = await requireAdminLogistics(event)
  const operatorId = getRouterParam(event, 'id')

  if (!operatorId) {
    throw createError({ statusCode: 400, statusMessage: 'ID operator tidak valid.' })
  }

  const supabase = getAdminSupabaseClient(event)
  const { data: operator, error } = await supabase
    .from('profiles')
    .select('id, email, full_name, phone_number, role, plant_location, created_at')
    .eq('id', operatorId)
    .eq('role', 'operator_logistics')
    .eq('plant_location', plantLocation)
    .maybeSingle()

  if (error) {
    console.error('Unable to load target logistics operator', error)
    throw createError({ statusCode: 500, statusMessage: 'Data operator gagal dimuat.' })
  }

  if (!operator) {
    throw createError({ statusCode: 404, statusMessage: 'Operator tidak ditemukan di plant ini.' })
  }

  return { operator, supabase }
}
