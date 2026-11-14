export type AppTheme = 'dark' | 'light'

function isAppTheme(value: unknown): value is AppTheme {
  return value === 'dark' || value === 'light'
}

export function useAppTheme() {
  const savedTheme = useCookie<AppTheme | null>('app-theme', {
    default: () => null,
    maxAge: 60 * 60 * 24 * 365,
    path: '/',
    sameSite: 'lax',
  })
  const theme = useState<AppTheme>('app-theme', () => (
    isAppTheme(savedTheme.value) ? savedTheme.value : 'light'
  ))
  const isThemeChanging = ref(false)
  let themeTransitionTimeout: ReturnType<typeof setTimeout> | undefined

  useHead(() => ({
    htmlAttrs: {
      class: [
        ...(theme.value === 'dark' ? ['dark'] : []),
        ...(isThemeChanging.value ? ['theme-changing'] : []),
      ].join(' ') || undefined,
    },
  }))

  function applyTheme(animate = false) {
    if (!import.meta.client) return

    if (animate) {
      isThemeChanging.value = true
      clearTimeout(themeTransitionTimeout)
      themeTransitionTimeout = setTimeout(() => {
        isThemeChanging.value = false
      }, 450)
    }
  }

  onMounted(() => {
    if (!isAppTheme(savedTheme.value)) {
      const legacyTheme = localStorage.getItem('app-theme')
      if (isAppTheme(legacyTheme)) {
        theme.value = legacyTheme
        return
      }
    }

    savedTheme.value = theme.value
  })

  watch(theme, (value) => {
    savedTheme.value = value
    applyTheme(true)
  })

  function toggleTheme() {
    theme.value = theme.value === 'dark' ? 'light' : 'dark'
  }

  return { theme, toggleTheme }
}
