module NDS
  # Net-new NDS toast; only renders in the NDS bucket. Add ?ui_test_bucket=nds
  # to the preview URL to load the NDS styles and see it.
  class ToastComponentPreview < BaseComponentPreview
    def default
      render(NDS::ToastComponent.new(message: 'Your changes were saved.'))
    end

    def custom_timing
      render(
        NDS::ToastComponent.new(
          message: 'Shows immediately and stays for eight seconds.',
          show_delay: 0,
          dismiss_after: 8000,
        ),
      )
    end

    # @param message text
    # @param show_delay number
    # @param dismiss_after number
    def workbench(message: 'Your changes were saved.', show_delay: 500, dismiss_after: 3000)
      render(
        NDS::ToastComponent.new(
          message:,
          show_delay:,
          dismiss_after:,
        ),
      )
    end
  end
end
