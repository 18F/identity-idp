class CaptchaSubmitButtonComponent < BaseComponent
  RECAPTCHA_SCRIPT_SRC = 'https://www.google.com/recaptcha/api.js'.freeze

  attr_reader :form, :action, :tag_options

  alias_method :f, :form

  # @param [String] action https://developers.google.com/recaptcha/docs/v3#actions
  def initialize(form:, action:, **tag_options)
    @form = form
    @action = action
    @tag_options = tag_options
  end

  def call
    content_tag(
      :'lg-captcha-submit-button',
      safe_join([input_errors_tag, input_tag, spinner_button_tag, recaptcha_script_tag]),
      **tag_options,
      'recaptcha-site-key': IdentityConfig.store.recaptcha_site_key,
      'recaptcha-action': action,
    )
  end

  private

  def spinner_button_tag
    render SpinnerButtonComponent.new(
      action_message: t('components.captcha_submit_button.action_message'),
      type: :submit,
      big: true,
      wide: true,
    ).with_content(content)
  end

  def input_errors_tag
    f.error(:recaptcha_token)
  end

  def input_tag
    f.input(:recaptcha_token, as: :hidden)
  end

  def recaptcha_script_tag
    return if IdentityConfig.store.recaptcha_site_key.blank?
    content_tag(:script, '', src: recaptcha_script_src, async: true)
  end

  def recaptcha_script_src
    UriService.add_params(RECAPTCHA_SCRIPT_SRC, render: IdentityConfig.store.recaptcha_site_key)
  end
end
