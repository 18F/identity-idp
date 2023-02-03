class CaptchaSubmitButtonComponent < SpinnerButtonComponent
  attr_reader :form, :action, :tag_options

  alias_method :f, :form

  # @param [String] action https://developers.google.com/recaptcha/docs/v3#actions
  def initialize(form:, action:, **tag_options)
    super(big: true, wide: true)

    @form = form
    @action = action
    @tag_options = tag_options
  end

  alias_method :spinner_button_tag, :call

  def call
    content_tag(
      :'lg-captcha-submit-button',
      safe_join([input_errors_tag, input_tag, spinner_button_tag, recaptcha_script_tag]),
      **tag_options,
      'recaptcha-site-key': IdentityConfig.store.recaptcha_site_key,
      'recaptcha-action': action,
    )
  end

  def content
    t('forms.buttons.submit.default')
  end

  private

  RECAPTCHA_SCRIPT_SRC = 'https://www.google.com/recaptcha/api.js'.freeze

  def input_errors_tag
    f.error(:recaptcha_token)
  end

  def input_tag
    f.input(:recaptcha_token, as: :hidden)
  end

  def recaptcha_script_tag
    content_tag(:script, '', src: recaptcha_script_src, async: true)
  end

  def recaptcha_script_src
    "#{RECAPTCHA_SCRIPT_SRC}?render=#{IdentityConfig.store.recaptcha_site_key}"
  end
end
