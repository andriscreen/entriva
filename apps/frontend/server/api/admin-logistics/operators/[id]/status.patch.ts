import { createError, defineEventHandler, readBody } from 'h3'
import { requireLogisticsOperator } from '../../../../utils/admin-logistics'

type OperatorStatusBody = {
  is_active?: unknown
}

export default defineEventHandler(async (event) => {
  const { operator, supabase } = await requireLogisticsOperator(event)
  const body = await readBody<OperatorStatusBody>(event)

  if (typeof body?.is_active !== 'boolean') {
    throw createError({ statusCode: 400, statusMessage: 'Status akun tidak valid.' })
  }

  const { data, error } = await supabase.auth.admin.updateUserById(operator.id, {
    ban_duration: body.is_active ? 'none' : '876000h',
  })

  if (error) {
    console.error('Unable to update logistics operator status', error)
    throw createError({ statusCode: 500, statusMessage: 'Status akun operator gagal diperbarui.' })
  }

  const bannedUntil = data.user.banned_until ? Date.parse(data.user.banned_until) : 0
  return { is_active: Number.isFinite(bannedUntil) && bannedUntil <= Date.now() }
})
