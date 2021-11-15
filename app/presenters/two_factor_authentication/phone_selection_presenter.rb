module TwoFactorAuthentication
  class PhoneSelectionPresenter < SelectionPresenter
    def method
      :phone
    end

    def type
      if MfaContext.new(configuration&.user).phone_configurations.many?
        "#{super}_#{configuration.id}"
      else
        super
      end
    end

    def info
      if configuration.present?
        t(
          "two_factor_authentication.#{option_mode}.phone_info_html",
          phone: masked_number(configuration.phone),
        )
      else
        voip_note = if IdentityConfig.store.voip_block
          t('two_factor_authentication.two_factor_choice_options.phone_info_no_voip')
        end

        safe_join([t("two_factor_authentication.#{option_mode}.phone_info_html"), *voip_note], ' ')
      end
    end

    def security_level
      t('two_factor_authentication.two_factor_choice_options.less_secure_label')
    end

    def disabled?
      VendorStatus.new.all_phone_vendor_outage?
    end

    private

    def masked_number(number)
      return '' if number.blank?
      "***-***-#{number[-4..-1]}"
    end
  end
end
