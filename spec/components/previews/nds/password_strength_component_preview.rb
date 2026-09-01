module NDS
  # Net-new NDS password strength meter; only renders in the NDS bucket. Add
  # ?ui_test_bucket=nds to the preview URL to load the NDS styles and see it.
  #
  # The meter attaches to an input by id and stays hidden until that input has a
  # value, so the host renders hidden here; type into a matching password field
  # on a real page to see the meter reveal and score.
  class PasswordStrengthComponentPreview < BaseComponentPreview
    def default
      render(NDS::PasswordStrengthComponent.new(input_id: 'preview_password'))
    end

    def with_forbidden_passwords
      render(
        NDS::PasswordStrengthComponent.new(
          input_id: 'preview_password',
          minimum_length: 12,
          forbidden_passwords: ['password', 'login.gov'],
        ),
      )
    end

    # @param minimum_length number
    def workbench(minimum_length: 12)
      render(
        NDS::PasswordStrengthComponent.new(
          input_id: 'preview_password',
          minimum_length: minimum_length.to_i,
        ),
      )
    end
  end
end
