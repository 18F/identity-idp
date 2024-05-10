# frozen_string_literal: true

class SignInRecaptchaForm
  RECAPTCHA_ACTION = 'sign_in'

  attr_reader :form_class, :form_args

  delegate :submit, :errors, to: :form

  def initialize(form_class: RecaptchaForm, **form_args)
    @form_class = form_class
    @form_args = form_args
  end

  private

  def form
    @form ||= form_class.new(
      score_threshold: IdentityConfig.store.sign_in_recaptcha_score_threshold,
      recaptcha_action: RECAPTCHA_ACTION,
      **form_args,
    )
  end
end
