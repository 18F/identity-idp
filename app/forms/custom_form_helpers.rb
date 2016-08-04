module CustomFormHelpers
  module PhoneHelpers
    def require_phone_confirmation?
      phone_changed? || phone_sms_enabled_changed?
    end

    def phone_sms_enabled_changed?
      @phone_sms_enabled_changed == true
    end

    def phone_changed?
      @phone_changed == true
    end

    private

    def check_phone_change(params)
      formatted_phone = params[:phone].phony_formatted(
        format: :international, normalize: :US, spaces: ' '
      )

      return unless formatted_phone != @user.phone

      @phone_changed = true
      self.phone = formatted_phone
    end

    def check_sms_preference_change(params)
      if form_changed_delivery_preference?(params)
        @phone_sms_enabled_changed = true
        self.phone_sms_enabled = params[:phone_sms_enabled].to_i == 1
      end
    end

    def form_changed_delivery_preference?(params)
      @user.phone_sms_enabled != (params[:phone_sms_enabled].to_i == 1 ? true : false)
    end
  end
end
