module RecaptchaConcern
  extend ActiveSupport::Concern

  private

  RECAPTCHA_SCRIPT_SRC = [
    'https://www.google.com/recaptcha/',
    'https://www.gstatic.com/recaptcha/',
  ].freeze

  RECAPTCHA_FRAME_SRC = [
    'https://www.google.com/recaptcha/',
    'https://recaptcha.google.com/recaptcha/',
  ].freeze

  def allow_csp_recaptcha_src
    policy = current_content_security_policy
    policy.script_src(*policy.script_src, *RECAPTCHA_SCRIPT_SRC)
    policy.frame_src(*policy.frame_src, *RECAPTCHA_FRAME_SRC)
    request.content_security_policy = policy
  end
end
