# frozen_string_literal: true

class CaptchaSubmitButtonComponent < BaseComponent
  attr_reader :form, :action, :tag_options

  alias_method :f, :form

  # @param [String] action https://developers.google.com/recaptcha/docs/v3#actions
  def initialize(form:, action:, **tag_options)
    @form = form
    @action = action
    @tag_options = tag_options
  end

  def show_mock_score_field?
    IdentityConfig.store.phone_recaptcha_mock_validator
  end

  def recaptcha_script_src
    return @recaptcha_script_src if defined?(@recaptcha_script_src)
    @recaptcha_script_src = begin
      if IdentityConfig.store.recaptcha_site_key_v3.present?
        UriService.add_params(
          recaptcha_enterprise? ?
            'https://www.google.com/recaptcha/enterprise.js' :
            'https://www.google.com/recaptcha/api.js',
          render: IdentityConfig.store.recaptcha_site_key_v3,
        )
      end
    end
  end

  def recaptcha_enterprise?
    FeatureManagement.recaptcha_enterprise?
  end
end
