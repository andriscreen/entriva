import { createError, defineEventHandler, readBody } from 'h3'
import { getAdminSupabaseClient, requireAdminLogistics } from '../../utils/admin-logistics'

type CreateVendorBody = {
  name?: unknown
  company_code?: unknown
  contact_person?: unknown
  phone_number?: unknown
}

export default defineEventHandler(async (event) => {
  await requireAdminLogistics(event)
  const body = await readBody<CreateVendorBody>(event)

  const name = typeof body?.name === 'string' ? body.name.trim() : ''
  const companyCode = typeof body?.company_code === 'string' ? body.company_code.trim() : ''
  const contactPerson = typeof body?.contact_person === 'string' ? body.contact_person.trim() : ''
  const phoneNumber = typeof body?.phone_number === 'string' ? body.phone_number.trim() : ''

  if (!name || name.length > 160) {
    throw createError({ statusCode: 400, statusMessage: 'Nama vendor wajib diisi dan maksimal 160 karakter.' })
  }
  if (companyCode.length > 80 || contactPerson.length > 120 || phoneNumber.length > 40) {
    throw createError({ statusCode: 400, statusMessage: 'Periksa kembali panjang kode, kontak, atau nomor telepon.' })
  }

  const supabase = getAdminSupabaseClient(event)
  const { data: vendor, error } = await supabase
    .from('vendors')
    .insert({
      name,
      company_code: companyCode || null,
      contact_person: contactPerson || null,
      phone_number: phoneNumber || null,
    })
    .select('id, name, company_code, contact_person, phone_number, created_at')
    .single()

  if (error) {
    console.error('Unable to create vendor', error)
    if (error.code === '23505') {
      throw createError({ statusCode: 409, statusMessage: 'Kode perusahaan tersebut sudah digunakan.' })
    }
    throw createError({ statusCode: 500, statusMessage: 'Vendor gagal disimpan.' })
  }

  return { vendor }
})
