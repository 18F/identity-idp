# frozen_string_literal: true

# Base class for the flow-specific reCAPTCHA forms (account creation, password
# reset, sign in). Each subclass supplies the reCAPTCHA action name and the
# rules that decide whether a request is `exempt?` and, when not, what score
# threshold applies. The shared logic — submitting the token to the underlying
# reCAPTCHA form and surfacing its validation errors — lives here.
#
# Subclasses MUST define:
#   - RECAPTCHA_ACTION           the reCAPTCHA action string
#   - #exempt?                   whether the reCAPTCHA check is skipped
#   - #score_threshold           the passing score when not exempt
class RecaptchaForm
  include ActiveModel::Model

  attr_reader :form_class, :form_args, :recaptcha_token, :assessment_id

  validate :validate_recaptcha_result

  def initialize(form_class:, **form_args)
    @form_class = form_class
    @form_args = form_args
  end

  def submit(recaptcha_token:)
    @recaptcha_token = recaptcha_token

    success = valid?
    FormResponse.new(success:, errors:)
  end

  def exempt?
    raise NotImplementedError, "#{self.class} must implement #exempt?"
  end

  private

  def recaptcha_action
    self.class::RECAPTCHA_ACTION
  end

  def score_threshold
    raise NotImplementedError, "#{self.class} must implement #score_threshold"
  end

  def validate_recaptcha_result
    recaptcha_response, @assessment_id = recaptcha_form.submit(recaptcha_token)
    errors.merge!(recaptcha_form) if !recaptcha_response.success?
  end

  def recaptcha_form
    @recaptcha_form ||= form_class.new(
      score_threshold:,
      recaptcha_action:,
      **form_args,
    )
  end
end
