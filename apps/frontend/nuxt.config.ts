/**
 * @author Andri Irawan
 * @project Entriva
 * @copyright 2026 Andri Digital
 */

import tailwindcss from '@tailwindcss/vite'

// https://nuxt.com/docs/api/configuration/nuxt-config
export default defineNuxtConfig({
  modules: ['@nuxtjs/supabase'],
  components: {
    dirs: [
      {
        path: '~/components',
        ignore: ['**/index.ts'],
      },
    ],
  },
  css: ['~/assets/css/main.css'],
  compatibilityDate: '2025-07-15',
  devtools: { enabled: true },
  supabase: {
    redirect: false,
  },
  vite: {
    plugins: [tailwindcss()],
  },
  app: {
    head: {
      title: 'Entriva Access Portal',
      meta: [
        { name: 'viewport', content: 'width=device-width, initial-scale=1' }
      ]
    }
  }
})
