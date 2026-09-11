# frozen_string_literal: true

class AccountCreationRecaptchaForm
  include ActiveModel::Model

  RECAPTCHA_ACTION = 'account_creation'

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
    score_threshold.zero?
  end

  private

  def validate_recaptcha_result
    recaptcha_response, @assessment_id = recaptcha_form.submit(recaptcha_token)
    errors.merge!(recaptcha_form) if !recaptcha_response.success?
  end

  def score_threshold
    IdentityConfig.store.account_creation_recaptcha_score_threshold
  end

  def recaptcha_form
    @recaptcha_form ||= form_class.new(
      score_threshold:,
      recaptcha_action: RECAPTCHA_ACTION,
      **form_args,
    )
  end
end
