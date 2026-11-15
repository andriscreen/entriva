import { createError, defineEventHandler } from 'h3'
import { serverSupabaseServiceRole } from '#supabase/server'

export default defineEventHandler(async (event) => {
  let supabase

  try {
    supabase = serverSupabaseServiceRole(event)
  } catch (error) {
    console.error('Unable to access vendors for the public logistics form', error)
    throw createError({
      statusCode: 503,
      statusMessage: 'Daftar vendor belum dapat diakses.',
    })
  }

  const { data, error } = await supabase
    .from('vendors')
    .select('id, name')
    .order('name', { ascending: true })

  if (error) {
    console.error('Unable to load public logistics vendors', error)
    throw createError({
      statusCode: 500,
      statusMessage: 'Daftar vendor gagal dimuat.',
    })
  }

  return { vendors: data ?? [] }
})
