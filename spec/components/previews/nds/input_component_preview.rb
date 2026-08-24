module NDS
  # Net-new NDS enhanced input. Add ?ui_test_bucket=nds to the preview URL to
  # load the NDS styles and see the floating label, phone, and password variants.
  class InputComponentPreview < BaseComponentPreview
    def default
      render(
        NDS::InputComponent.new(
          form: form_builder,
          attribute: :full_name,
          label: 'Full name',
        ),
      )
    end

    def email
      render(
        NDS::InputComponent.new(
          form: form_builder,
          attribute: :email,
          label: 'Email address',
          type: :email,
        ),
      )
    end

    def password
      render(
        NDS::InputComponent.new(
          form: form_builder,
          attribute: :password,
          label: 'Password',
          type: :password,
        ),
      )
    end

    def phone
      render(
        NDS::InputComponent.new(
          form: form_builder,
          attribute: :phone,
          label: 'Phone number',
          type: :tel,
          country_selector: true,
        ),
      )
    end

    def static_label
      render(
        NDS::InputComponent.new(
          form: form_builder,
          attribute: :full_name,
          label: 'Full name',
          floating_label: false,
          placeholder: 'First and last',
        ),
      )
    end

    def with_error
      render(
        NDS::InputComponent.new(
          form: form_builder,
          attribute: :email,
          label: 'Email address',
          type: :email,
          error_message: 'Enter a valid email address',
        ),
      )
    end

    # @param label text
    # @param type select [text,email,password,tel,date]
    # @param floating_label toggle
    # @param country_selector toggle
    # @param error_message text
    def workbench(
      label: 'Full name',
      type: :text,
      floating_label: true,
      country_selector: false,
      error_message: nil
    )
      render(
        NDS::InputComponent.new(
          form: form_builder,
          attribute: :workbench_field,
          label:,
          type: type&.to_sym,
          floating_label:,
          country_selector:,
          error_message: error_message.presence,
        ),
      )
    end
  end
end
