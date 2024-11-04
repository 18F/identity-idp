# frozen_string_literal: true

class RecaptchaForm
  include ActiveModel::Model
  include ActionView::Helpers::TranslationHelper

  VERIFICATION_ENDPOINT = 'https://www.google.com/recaptcha/api/siteverify'
  RESULT_ERRORS = ['missing-input-secret', 'invalid-input-secret'].freeze
  EXEMPT_RESULT_REASONS = ['LOW_CONFIDENCE_SCORE'].freeze

  attr_reader :recaptcha_action,
              :recaptcha_token,
              :score_threshold,
              :analytics,
              :extra_analytics_properties

  validate :validate_token_exists
  validate :validate_recaptcha_result

  RecaptchaResult = Struct.new(
    :success,
    :assessment_id,
    :score,
    :errors,
    :reasons,
    keyword_init: true,
  ) do
    alias_method :success?, :success

    def initialize(success:, assessment_id: nil, score: nil, errors: [], reasons: [])
      super
    end
  end

  def initialize(
    recaptcha_action: nil,
    score_threshold: 0.0,
    analytics: nil,
    extra_analytics_properties: {}
  )
    @score_threshold = score_threshold
    @analytics = analytics
    @recaptcha_action = recaptcha_action
    @extra_analytics_properties = extra_analytics_properties
  end

  def exempt?
    !score_threshold.positive?
  end

  # @return [Array(Boolean, String), Array(Boolean, nil)]
  def submit(recaptcha_token)
    @recaptcha_token = recaptcha_token
    @recaptcha_result = recaptcha_result if recaptcha_token.present? && !exempt?

    log_analytics(result: @recaptcha_result) if @recaptcha_result
    response = FormResponse.new(success: valid?, errors:, serialize_error_details_only: true)
    [response, @recaptcha_result&.assessment_id]
  rescue Faraday::Error => error
    log_analytics(error:)
    response = FormResponse.new(success: true, serialize_error_details_only: true)
    [response, nil]
  end

  private

  def validate_token_exists
    return if exempt? || recaptcha_token.present?
    errors.add(:recaptcha_token, :blank, message: t('errors.messages.invalid_recaptcha_token'))
  end

  def validate_recaptcha_result
    return if @recaptcha_result.blank? || recaptcha_result_valid?(@recaptcha_result)
    errors.add(:recaptcha_token, :invalid, message: t('errors.messages.invalid_recaptcha_token'))
  end

  def recaptcha_result
    response = faraday.post(
      VERIFICATION_ENDPOINT,
      URI.encode_www_form(secret: recaptcha_secret_key, response: recaptcha_token),
    ) do |request|
      request.options.context = { service_name: 'recaptcha' }
    end

    success, score, error_codes = response.body.values_at('success', 'score', 'error-codes')
    errors, reasons = error_codes.to_a.partition { |error_code| result_error?(error_code) }
    RecaptchaResult.new(success:, score:, errors:, reasons:)
  end

  def faraday
    Faraday.new do |conn|
      conn.request :instrumentation, name: 'request_log.faraday'
      conn.response :json
    end
  end

  def recaptcha_result_valid?(result)
    return true if result.blank?
    return true if result_reason_exempt?(result)

    if result.success?
      result.score >= score_threshold
    else
      result.errors.present?
    end
  end

  def result_error?(error_code)
    RESULT_ERRORS.include?(error_code)
  end

  def result_reason_exempt?(result)
    (EXEMPT_RESULT_REASONS & result.reasons).any?
  end

  def log_analytics(result: nil, error: nil)
    analytics&.recaptcha_verify_result_received(
      recaptcha_result: result.to_h.presence,
      score_threshold:,
      evaluated_as_valid: recaptcha_result_valid?(result),
      exception_class: error&.class&.name,
      form_class: self.class.name,
      recaptcha_action:,
      **extra_analytics_properties,
    )
  end

  def recaptcha_secret_key
    IdentityConfig.store.recaptcha_secret_key
  end
end
