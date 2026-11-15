import { createError, defineEventHandler, readBody } from 'h3'
import { requireLogisticsOperator } from '../../../../utils/admin-logistics'

type ResetOperatorPasswordBody = {
  password?: unknown
}

export default defineEventHandler(async (event) => {
  const { operator, supabase } = await requireLogisticsOperator(event)
  const body = await readBody<ResetOperatorPasswordBody>(event)
  const password = typeof body?.password === 'string' ? body.password : ''

  if (password.length < 8 || password.length > 128) {
    throw createError({ statusCode: 400, statusMessage: 'Kata sandi harus terdiri dari 8–128 karakter.' })
  }

  const { error } = await supabase.auth.admin.updateUserById(operator.id, { password })
  if (error) {
    console.error('Unable to reset logistics operator password', error)
    throw createError({ statusCode: 500, statusMessage: 'Kata sandi operator gagal direset.' })
  }

  return { success: true }
})
