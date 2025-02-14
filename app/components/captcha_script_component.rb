# frozen_string_literal: true

class CaptchaScriptComponent < BaseComponent
  def recaptcha_script_src
    return @recaptcha_script_src if defined?(@recaptcha_script_src)
    @recaptcha_script_src =
      if IdentityConfig.store.recaptcha_site_key.present?
        UriService.add_params(
          recaptcha_enterprise? ?
            'https://www.google.com/recaptcha/enterprise.js' :
            'https://www.google.com/recaptcha/api.js',
          render: IdentityConfig.store.recaptcha_site_key,
        )
      end
  end

  def recaptcha_enterprise?
    FeatureManagement.recaptcha_enterprise?
  end
end
