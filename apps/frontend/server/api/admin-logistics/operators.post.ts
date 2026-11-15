import { createError, defineEventHandler, readBody } from 'h3'
import { getAdminSupabaseClient, requireAdminLogistics } from '../../utils/admin-logistics'

type CreateOperatorBody = {
  email?: unknown
  full_name?: unknown
  phone_number?: unknown
  password?: unknown
}

export default defineEventHandler(async (event) => {
  const { plantLocation } = await requireAdminLogistics(event)
  const body = await readBody<CreateOperatorBody>(event)

  const email = typeof body?.email === 'string' ? body.email.trim().toLowerCase() : ''
  const fullName = typeof body?.full_name === 'string' ? body.full_name.trim() : ''
  const phoneNumber = typeof body?.phone_number === 'string' ? body.phone_number.trim() : ''
  const password = typeof body?.password === 'string' ? body.password : ''

  if (!email || !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) {
    throw createError({ statusCode: 400, statusMessage: 'Alamat email tidak valid.' })
  }
  if (!fullName || fullName.length > 120) {
    throw createError({ statusCode: 400, statusMessage: 'Nama wajib diisi dan maksimal 120 karakter.' })
  }
  if (phoneNumber.length > 40) {
    throw createError({ statusCode: 400, statusMessage: 'Nomor telepon maksimal 40 karakter.' })
  }
  if (password.length < 8 || password.length > 128) {
    throw createError({ statusCode: 400, statusMessage: 'Kata sandi harus terdiri dari 8–128 karakter.' })
  }

  const supabase = getAdminSupabaseClient(event)
  const { data: authResult, error: authError } = await supabase.auth.admin.createUser({
    email,
    password,
    email_confirm: true,
    user_metadata: { full_name: fullName },
  })

  if (authError) {
    console.error('Unable to create operator auth account', authError)
    const alreadyExists = authError.code === 'email_exists'
      || authError.message.toLowerCase().includes('already registered')
    throw createError({
      statusCode: alreadyExists ? 409 : 400,
      statusMessage: alreadyExists ? 'Email tersebut sudah terdaftar.' : 'Akun operator gagal dibuat.',
    })
  }

  const authUser = authResult.user
  if (!authUser) {
    throw createError({
      statusCode: 500,
      statusMessage: 'Supabase tidak mengembalikan akun operator yang dibuat.',
    })
  }

  const { data: operator, error: profileError } = await supabase
    .from('profiles')
    .insert({
      id: authUser.id,
      email,
      full_name: fullName,
      phone_number: phoneNumber || null,
      role: 'operator_logistics',
      plant_location: plantLocation,
    })
    .select('id, email, full_name, phone_number, role, plant_location, created_at')
    .single()

  if (profileError) {
    console.error('Unable to create operator profile; removing auth account', profileError)
    const { error: cleanupError } = await supabase.auth.admin.deleteUser(authUser.id)

    if (cleanupError) {
      console.error('Unable to remove orphaned operator auth account', {
        userId: authUser.id,
        error: cleanupError,
      })
      throw createError({
        statusCode: 500,
        statusMessage: 'Profil operator gagal dibuat dan akun autentikasi gagal dibersihkan. Hubungi administrator.',
      })
    }

    throw createError({
      statusCode: profileError.code === '23505' ? 409 : 500,
      statusMessage: profileError.code === '23505'
        ? 'Akun dengan email tersebut sudah memiliki profil.'
        : 'Profil operator gagal dibuat.',
    })
  }

  return { operator }
})
