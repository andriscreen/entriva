export function useSuccessModal() {
  const message = useState<string | null>('global-success-modal', () => null)

  function showSuccess(successMessage: string) {
    message.value = successMessage
  }

  function closeSuccess() {
    message.value = null
  }

  return {
    message,
    showSuccess,
    closeSuccess,
  }
}
