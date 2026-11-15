
<script setup lang="ts">
import {
  ArrowRight,
  Eye,
  EyeOff,
  KeyRound,
  LoaderCircle,
  Mail,
  ShieldCheck,
} from 'lucide-vue-next'

import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import { getDashboardPath } from '@/utils/auth'

const form = reactive({
  email: '',
  password: '',
})

const supabase = useSupabaseClient()
const route = useRoute()

const isSubmitting = ref(false)
const showPassword = ref(false)
const loginError = ref('')
const loginBackground = ref<HTMLElement | null>(null)

type VantaWindow = Window & {
  VANTA?: {
    WAVES: (options: Record<string, unknown>) => { destroy: () => void }
  }
}

let wavesEffect: { destroy: () => void } | undefined

function loadScript(src: string) {
  return new Promise<void>((resolve, reject) => {
    const existingScript = document.querySelector<HTMLScriptElement>(`script[src="${src}"]`)

    if (existingScript?.dataset.loaded === 'true') {
      resolve()
      return
    }

    const script = existingScript ?? document.createElement('script')
    script.addEventListener('load', () => {
      script.dataset.loaded = 'true'
      resolve()
    }, { once: true })
    script.addEventListener('error', () => reject(new Error(`Unable to load ${src}`)), { once: true })

    if (!existingScript) {
      script.src = src
      script.async = true
      document.head.appendChild(script)
    }
  })
}

onMounted(async () => {
  try {
    await loadScript('https://cdnjs.cloudflare.com/ajax/libs/three.js/r134/three.min.js')
    await loadScript('https://cdn.jsdelivr.net/npm/vanta@latest/dist/vanta.waves.min.js')

    const vanta = (window as VantaWindow).VANTA
    if (!vanta || !loginBackground.value) return

    wavesEffect = vanta.WAVES({
      el: loginBackground.value,
      mouseControls: true,
      touchControls: true,
      gyroControls: false,
      minHeight: 200,
      minWidth: 200,
      scale: 1,
      scaleMobile: 1,
      color: 0x4a4a4a,
      shininess: 32,
      waveHeight: 13,
      waveSpeed: 0.45,
      zoom: 1.25,
    })
  } catch (error) {
    console.warn('Unable to initialize the login background animation', error)
  }
})

onBeforeUnmount(() => wavesEffect?.destroy())

const routeError = computed(() => {
  switch (route.query.error) {
    case 'session':
      return 'Sesi tidak dapat diverifikasi. Silakan masuk kembali.'
    case 'profile':
      return 'Profil akun tidak ditemukan. Hubungi administrator.'
    case 'role':
      return 'Akun ini belum memiliki role akses yang valid. Hubungi administrator.'
    default:
      return ''
  }
})

async function handleLogin() {
  if (isSubmitting.value) return

  isSubmitting.value = true
  loginError.value = ''

  try {
    const { data, error } = await supabase.auth.signInWithPassword({
      email: form.email,
      password: form.password,
    })

    if (error) {
      loginError.value = error.message
      return
    }

    const { data: profile, error: profileError } = await supabase
      .from('profiles')
      .select('role')
      .eq('id', data.user.id)
      .single()

    if (profileError) {
      await supabase.auth.signOut()
      loginError.value = 'Profil akun tidak ditemukan. Hubungi administrator.'
      return
    }

    const dashboardPath = getDashboardPath(profile.role)

    if (!dashboardPath) {
      await supabase.auth.signOut()
      loginError.value = 'Akun ini belum memiliki role akses yang valid. Hubungi administrator.'
      return
    }

    await navigateTo(dashboardPath)
  } catch (error) {
    console.error('Supabase login failed', error)
    loginError.value = 'Tidak dapat terhubung ke layanan login. Silakan coba lagi.'
  } finally {
    isSubmitting.value = false
  }
}
</script>

<template>
  <main
    ref="loginBackground"
    class="relative flex min-h-screen items-center justify-center overflow-hidden bg-[#171717] px-4 py-8 sm:px-8"
  >

    <!-- Login Window -->
    <div
      class="relative z-10 grid w-full max-w-[1160px] overflow-hidden rounded-2xl border border-white/10 bg-[#171717] shadow-2xl shadow-black/60 lg:min-h-[680px] lg:grid-cols-2"
    >
      <!-- Left: Login Form -->
      <section
        class="relative flex min-h-[620px] flex-col bg-[#171717] px-6 py-8 text-white sm:px-12 lg:px-14 lg:py-10"
      >
        <!-- Window controls -->
        <div class="mb-10 flex items-center gap-2">
          <span class="size-3 rounded-full bg-[#FF5F57]" />
          <span class="size-3 rounded-full bg-[#FEBC2E]" />
          <span class="size-3 rounded-full bg-[#28C840]" />
        </div>

        <!-- Brand -->
        <NuxtLink
          to="/login"
          aria-label="Entriva Home"
          class="mx-auto mb-12 flex w-fit items-center gap-3"
        >
          <img
            src="/img/entrivaputih.png"
            alt="ENTRIVA"
            class="h-11 w-auto object-contain"
          />
          <span class="text-xl font-bold tracking-[0.18em] text-white">
            ENTRIVA
          </span>
        </NuxtLink>

        <!-- Form Content -->
        <div class="mx-auto flex w-full max-w-[390px] flex-1 flex-col justify-center">
          <div class="mb-8 text-center">
            <div
              class="mx-auto flex items-center justify-center rounded-2xl text-yellow-400"
            >
            </div>

            <h1 class="text-3xl font-bold tracking-tight text-white">
              Welcome back
            </h1>

            <p class="mt-3 text-sm leading-relaxed text-slate-400">
              Sign in to access your ENTRIVA workspace.
            </p>
          </div>

          <form class="space-y-5" @submit.prevent="handleLogin">
            <!-- Email -->
            <div class="space-y-2">
              <Label for="email" class="text-sm font-medium text-slate-300">
                Email address
              </Label>

              <div class="relative">
                <Mail
                  class="pointer-events-none absolute left-3.5 top-1/2 size-4 -translate-y-1/2 text-slate-500"
                />

                <Input
                  id="email"
                  v-model="form.email"
                  type="email"
                  autocomplete="username"
                  placeholder="hi@entriva.com"
                  required
                  class="h-12 border-white/10 bg-white/[0.04] pl-10 text-white placeholder:text-slate-500 focus-visible:border-yellow-400 focus-visible:bg-white/[0.07] focus-visible:ring-yellow-400/20"
                />
              </div>
            </div>

            <!-- Password -->
            <div class="space-y-2">
              <Label for="password" class="text-sm font-medium text-slate-300">
                Password
              </Label>

              <div class="relative">
                <KeyRound
                  class="pointer-events-none absolute left-3.5 top-1/2 size-4 -translate-y-1/2 text-slate-500"
                />

                <Input
                  id="password"
                  v-model="form.password"
                  :type="showPassword ? 'text' : 'password'"
                  autocomplete="current-password"
                  placeholder="Enter your password"
                  required
                  class="h-12 border-white/10 bg-white/[0.04] pl-10 pr-12 text-white placeholder:text-slate-500 focus-visible:border-yellow-400 focus-visible:bg-white/[0.07] focus-visible:ring-yellow-400/20"
                />

                <Button
                  type="button"
                  variant="ghost"
                  size="icon"
                  class="absolute right-1 top-1/2 size-10 -translate-y-1/2 text-slate-500 hover:bg-white/5 hover:text-white"
                  :aria-label="showPassword ? 'Hide password' : 'Show password'"
                  :aria-pressed="showPassword"
                  @click="showPassword = !showPassword"
                >
                  <EyeOff v-if="showPassword" class="size-4" />
                  <Eye v-else class="size-4" />
                </Button>
              </div>
            </div>

            <!-- Error -->
            <p
              v-if="loginError || routeError"
              role="alert"
              class="rounded-lg border border-red-500/20 bg-red-500/10 px-4 py-3 text-sm leading-relaxed text-red-400"
            >
              {{ loginError || routeError }}
            </p>

            <!-- Submit -->
            <Button
              type="submit"
              :disabled="isSubmitting"
              class="h-12 w-full gap-2 bg-yellow-400 text-sm font-semibold text-black shadow-lg shadow-yellow-950/20 hover:bg-yellow-300 disabled:opacity-60"
            >
              <LoaderCircle
                v-if="isSubmitting"
                class="size-4 animate-spin"
              />

              <template v-else>
                Sign in
                <ArrowRight class="size-4" />
              </template>
            </Button>
          </form>

        </div>

        <!-- Footer -->
        <div class="mt-10 text-center text-xs text-slate-500">
          © {{ new Date().getFullYear() }} ENTRIVA. All rights reserved.
        </div>
      </section>

      <!-- Right: Visual Panel -->
      <section
        class="relative hidden min-h-[260px] overflow-hidden bg-[#1a170a] lg:order-last lg:block lg:min-h-full"
      >
        <img
          src="/img/imagecover.png"
          alt="ENTRIVA guest, vendor, and logistics management"
          class="absolute inset-0 size-full object-cover"
        />

        <div
          class="absolute inset-0 bg-gradient-to-t from-[#090909]/95 via-[#090909]/20 to-[#090909]/10"
        />

        
        <div class="absolute inset-x-0 bottom-0 p-7 text-white sm:p-10 lg:p-12">

          <h2 class="max-w-lg text-3xl font-bold leading-tight tracking-tight sm:text-4xl">
            Guest Management
            <span class="text-yellow-300">Platform.</span>
          </h2>

          <p class="mt-4 max-w-md text-sm leading-relaxed text-slate-200/80">
            Seamless Visits. Smarter Management.
          </p>

        </div>
      </section>
    </div>
  </main>
</template>
