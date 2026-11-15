import { createError, defineEventHandler } from 'h3'
import { requireLogisticsOperator } from '../../../utils/admin-logistics'

export default defineEventHandler(async (event) => {
  const { operator, supabase } = await requireLogisticsOperator(event)

  const { error: snapshotError } = await supabase
    .from('logistics_queues')
    .update({
      approved_by_name: operator.full_name,
      approved_by: null,
    })
    .eq('approved_by', operator.id)

  if (snapshotError) {
    console.error('Unable to preserve operator approval history before deletion', snapshotError)
    throw createError({
      statusCode: 500,
      statusMessage: 'Riwayat persetujuan operator gagal diamankan. Akun belum dihapus.',
    })
  }

  const { error } = await supabase.auth.admin.deleteUser(operator.id)
  if (error) {
    console.error('Unable to delete logistics operator account', error)
    throw createError({ statusCode: 500, statusMessage: 'Akun operator gagal dihapus.' })
  }

  return { success: true }
})
