class CaptchaSubmitButtonComponent < SpinnerButtonComponent
  attr_reader :action, :tag_options

  # @param [String] action https://developers.google.com/recaptcha/docs/v3#actions
  def initialize(action:, **tag_options)
    super(big: true, wide: true)

    @action = action
    @tag_options = tag_options
  end

  alias_method :spinner_button_tag, :call

  def call
    button_tag + recaptcha_script_tag
  end

  def content
    t('forms.buttons.submit.default')
  end

  private

  RECAPTCHA_SCRIPT_SRC = 'https://www.google.com/recaptcha/api.js'.freeze

  def button_tag
    content_tag(
      :'lg-captcha-submit-button',
      spinner_button_tag,
      **tag_options,
      'recaptcha-site-key': IdentityConfig.store.recaptcha_site_key,
      'recaptcha-action': action,
    )
  end

  def recaptcha_script_tag
    content_tag(:script, '', src: recaptcha_script_src, async: true)
  end

  def recaptcha_script_src
    "#{RECAPTCHA_SCRIPT_SRC}?render=#{IdentityConfig.store.recaptcha_site_key}"
  end
end
