<script setup lang="ts">
import {
  ArrowLeft,
  Check,
  KeyRound,
  LoaderCircle,
  Mail,
  MapPin,
  Save,
  ShieldCheck,
  UserRound,
} from 'lucide-vue-next'
import { Avatar, AvatarFallback, AvatarImage } from '@/components/ui/avatar'
import { Button } from '@/components/ui/button'
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import { getDashboardPath } from '@/utils/auth'

definePageMeta({
  layout: 'dashboard',
  path: '/account/editprofile',
})

const supabase = useSupabaseClient()
const user = useSupabaseUser()
const accountAvatarPath = useState('account-avatar-path', () => '')

const avatarOptions = Array.from({ length: 18 }, (_, index) => `/avatar/avatar${index + 1}.jpg`)
const plantOptions = ['Jatake 1', 'Jatake 2', 'Jatake 3', 'Jatake 6']

const profile = reactive({
  fullName: '',
  phoneNumber: '',
  plantLocation: 'Jatake 1',
  role: '',
  avatarPath: '',
})
const passwordForm = reactive({
  password: '',
  confirmPassword: '',
})

const isLoading = ref(true)
const profileUserId = ref('')
const isSavingProfile = ref(false)
const isSavingPassword = ref(false)
const profileError = ref('')
const passwordError = ref('')
const { showSuccess } = useSuccessModal()

const accountEmail = computed(() => user.value?.email ?? '')
const selectedAvatar = computed(() => profile.avatarPath || avatarOptions[0])

onMounted(loadProfile)

async function loadProfile() {
  isLoading.value = true
  profileError.value = ''

  try {
    const { data: authData, error: authError } = await supabase.auth.getUser()
    if (authError) throw authError
    if (!authData.user) {
      profileUserId.value = ''
      await navigateTo('/login')
      return
    }
    profileUserId.value = authData.user.id

    const { data, error } = await supabase
      .from('profiles')
      .select('full_name, phone_number, plant_location, role, avatar_path')
      .eq('id', authData.user.id)
      .single()

    if (error) throw error

    profile.fullName = data.full_name
    profile.phoneNumber = data.phone_number ?? ''
    profile.plantLocation = data.plant_location ?? 'Jatake 1'
    profile.role = data.role

    profile.avatarPath = typeof data.avatar_path === 'string' && avatarOptions.includes(data.avatar_path)
      ? data.avatar_path
      : avatarOptions[0]
    accountAvatarPath.value = profile.avatarPath
  } catch (error) {
    console.error('Failed to load profile', error)
    profileError.value = 'Profil gagal dimuat. Silakan coba lagi.'
  } finally {
    isLoading.value = false
  }
}

async function saveProfile() {
  if (isSavingProfile.value) return

  isSavingProfile.value = true
  profileError.value = ''

  if (!profileUserId.value) {
    profileError.value = 'Sesi akun tidak tersedia. Muat ulang halaman dan coba lagi.'
    isSavingProfile.value = false
    return
  }

  const fullName = profile.fullName.trim()
  if (!fullName) {
    profileError.value = 'Nama lengkap wajib diisi.'
    isSavingProfile.value = false
    return
  }

  try {
    const { error: profileUpdateError } = await supabase
      .from('profiles')
      .update({
        full_name: fullName,
        phone_number: profile.phoneNumber.trim() || null,
        plant_location: profile.plantLocation,
        avatar_path: selectedAvatar.value,
        updated_at: new Date().toISOString(),
      })
      .eq('id', profileUserId.value)

    if (profileUpdateError) throw profileUpdateError

    profile.fullName = fullName
    profile.avatarPath = selectedAvatar.value
    accountAvatarPath.value = selectedAvatar.value

    const { error: metadataError } = await supabase.auth.updateUser({
      data: {
        full_name: fullName,
      },
    })

    if (metadataError) {
      profileError.value = 'Profil tersimpan, tetapi nama akun gagal diperbarui.'
      console.error('Failed to update account metadata', metadataError)
      return
    }

    showSuccess('Profil berhasil diperbarui.')
  } catch (error) {
    console.error('Failed to save profile', error)
    const details = error instanceof Error ? error.message : 'Kesalahan tidak dikenal.'
    profileError.value = `Perubahan profil gagal disimpan: ${details}`
  } finally {
    isSavingProfile.value = false
  }
}

async function savePassword() {
  if (isSavingPassword.value) return

  passwordError.value = ''

  if (passwordForm.password.length < 8) {
    passwordError.value = 'Kata sandi harus memiliki minimal 8 karakter.'
    return
  }
  if (passwordForm.password !== passwordForm.confirmPassword) {
    passwordError.value = 'Konfirmasi kata sandi tidak cocok.'
    return
  }

  isSavingPassword.value = true
  try {
    const { error } = await supabase.auth.updateUser({ password: passwordForm.password })
    if (error) throw error

    passwordForm.password = ''
    passwordForm.confirmPassword = ''
    showSuccess('Kata sandi berhasil diperbarui.')
  } catch (error) {
    console.error('Failed to update password', error)
    passwordError.value = 'Kata sandi gagal diperbarui. Silakan coba lagi.'
  } finally {
    isSavingPassword.value = false
  }
}

async function returnToDashboard() {
  const path = getDashboardPath(profile.role)
  if (!path) {
    profileError.value = 'Role akun tidak valid. Hubungi administrator.'
    return
  }

  await navigateTo(path)
}
</script>

<template>
  <div class="mx-auto max-w-5xl space-y-6">
    <div class="flex flex-wrap items-center justify-between gap-4">
      <div>
        <p class="text-sm text-muted-foreground">Account settings</p>
        <h1 class="mt-1 text-3xl font-semibold tracking-tight">Edit profile</h1>
        <p class="mt-2 text-sm text-muted-foreground">Kelola informasi akun dan preferensi profil Anda.</p>
      </div>
      <Button variant="outline" :disabled="isLoading" @click="returnToDashboard">
        <ArrowLeft class="size-4" />
        Kembali ke dashboard
      </Button>
    </div>

    <p
      v-if="profileError"
      role="alert"
      class="rounded-xl border border-red-500/20 bg-red-500/10 px-4 py-3 text-sm text-red-700 dark:text-red-300"
    >
      {{ profileError }}
    </p>

    <div v-if="isLoading" class="flex items-center justify-center rounded-2xl border bg-card p-12 text-muted-foreground">
      <LoaderCircle class="mr-2 size-4 animate-spin" />
      Memuat profil...
    </div>

    <template v-else>
      <Card>
        <CardHeader>
          <CardTitle class="flex items-center gap-2">
            <UserRound class="size-5 text-primary" />
            Informasi profil
          </CardTitle>
          <CardDescription>Perbarui nama, kontak, lokasi plant, dan avatar akun.</CardDescription>
        </CardHeader>
        <CardContent>
          <form class="space-y-7" @submit.prevent="saveProfile">
            <div class="flex flex-col gap-5 rounded-2xl border bg-muted/20 p-5 sm:flex-row sm:items-center">
              <Avatar class="size-20 border-2 border-primary/30">
                <AvatarImage :src="selectedAvatar" :alt="`Avatar ${profile.fullName}`" />
                <AvatarFallback>{{ profile.fullName.slice(0, 2).toUpperCase() || 'U' }}</AvatarFallback>
              </Avatar>
              <div>
                <p class="font-medium">Pilih avatar</p>
                <p class="mt-1 text-sm text-muted-foreground">Pilih salah satu avatar yang tersedia.</p>
              </div>
              <div class="grid grid-cols-6 gap-2 sm:ml-auto sm:grid-cols-9">
                <button
                  v-for="avatar in avatarOptions"
                  :key="avatar"
                  type="button"
                  class="relative rounded-full focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring focus-visible:ring-offset-2"
                  :aria-label="`Pilih ${avatar.split('/').pop()}`"
                  :aria-pressed="selectedAvatar === avatar"
                  @click="profile.avatarPath = avatar"
                >
                  <Avatar class="size-9 border-2 transition" :class="selectedAvatar === avatar ? 'border-primary ring-2 ring-primary/20' : 'border-transparent opacity-70 hover:opacity-100'">
                    <AvatarImage :src="avatar" alt="" />
                    <AvatarFallback>U</AvatarFallback>
                  </Avatar>
                  <span v-if="selectedAvatar === avatar" class="absolute -right-0.5 -top-0.5 flex size-4 items-center justify-center rounded-full bg-primary text-primary-foreground">
                    <Check class="size-3" />
                  </span>
                </button>
              </div>
            </div>

            <div class="grid gap-5 md:grid-cols-2">
              <div class="space-y-2">
                <Label for="full-name">Nama lengkap</Label>
                <Input id="full-name" v-model="profile.fullName" autocomplete="name" maxlength="120" required />
              </div>
              <div class="space-y-2">
                <Label for="email">Email</Label>
                <div class="relative">
                  <Mail class="pointer-events-none absolute left-3 top-1/2 size-4 -translate-y-1/2 text-muted-foreground" />
                  <Input id="email" :model-value="accountEmail" class="pl-9" type="email" disabled />
                </div>
                <p class="text-xs text-muted-foreground">Email dikelola oleh Supabase Auth dan tidak dapat diubah di sini.</p>
              </div>
              <div class="space-y-2">
                <Label for="phone-number">Nomor telepon</Label>
                <Input id="phone-number" v-model="profile.phoneNumber" type="tel" autocomplete="tel" maxlength="30" placeholder="Contoh: 081234567890" />
              </div>
              <div class="space-y-2">
                <Label for="plant-location">Lokasi plant</Label>
                <div class="relative">
                  <MapPin class="pointer-events-none absolute left-3 top-1/2 size-4 -translate-y-1/2 text-muted-foreground" />
                  <select
                    id="plant-location"
                    v-model="profile.plantLocation"
                    class="h-10 w-full appearance-none rounded-md border border-input bg-background px-3 pl-9 pr-8 text-sm shadow-xs outline-none focus-visible:border-ring focus-visible:ring-3 focus-visible:ring-ring/50"
                  >
                    <option v-for="plant in plantOptions" :key="plant" :value="plant">{{ plant }}</option>
                  </select>
                </div>
              </div>
              <div class="space-y-2">
                <Label for="role">Role</Label>
                <div class="relative">
                  <ShieldCheck class="pointer-events-none absolute left-3 top-1/2 size-4 -translate-y-1/2 text-muted-foreground" />
                  <Input id="role" :model-value="profile.role.replaceAll('_', ' ')" class="pl-9 capitalize" disabled />
                </div>
                <p class="text-xs text-muted-foreground">Role hanya dapat diubah oleh administrator.</p>
              </div>
            </div>

            <div class="flex justify-end border-t pt-5">
              <Button type="submit" :disabled="isSavingProfile">
                <LoaderCircle v-if="isSavingProfile" class="size-4 animate-spin" />
                <Save v-else class="size-4" />
                Simpan profil
              </Button>
            </div>
          </form>
        </CardContent>
      </Card>

      <Card>
        <CardHeader>
          <CardTitle class="flex items-center gap-2">
            <KeyRound class="size-5 text-primary" />
            Ganti kata sandi
          </CardTitle>
          <CardDescription>Gunakan kata sandi minimal 8 karakter.</CardDescription>
        </CardHeader>
        <CardContent>
          <form class="space-y-5" @submit.prevent="savePassword">
            <div class="grid gap-5 md:grid-cols-2">
              <div class="space-y-2">
                <Label for="new-password">Kata sandi baru</Label>
                <Input id="new-password" v-model="passwordForm.password" type="password" autocomplete="new-password" minlength="8" required />
              </div>
              <div class="space-y-2">
                <Label for="confirm-password">Konfirmasi kata sandi</Label>
                <Input id="confirm-password" v-model="passwordForm.confirmPassword" type="password" autocomplete="new-password" minlength="8" required />
              </div>
            </div>
            <p v-if="passwordError" role="alert" class="text-sm text-red-700 dark:text-red-300">{{ passwordError }}</p>
            <div class="flex justify-end border-t pt-5">
              <Button type="submit" variant="outline" :disabled="isSavingPassword">
                <LoaderCircle v-if="isSavingPassword" class="size-4 animate-spin" />
                <KeyRound v-else class="size-4" />
                Perbarui kata sandi
              </Button>
            </div>
          </form>
        </CardContent>
      </Card>
    </template>
  </div>
</template>
