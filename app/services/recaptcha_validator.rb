# frozen_string_literal: true

class RecaptchaValidator
  VERIFICATION_ENDPOINT = 'https://www.google.com/recaptcha/api/siteverify'
  RESULT_ERRORS = ['missing-input-secret', 'invalid-input-secret']
  VALID_RECAPTCHA_VERSIONS = [2, 3]

  attr_reader :recaptcha_version,
              :recaptcha_action,
              :score_threshold,
              :analytics,
              :extra_analytics_properties

  RecaptchaResult = Struct.new(:success, :score, :errors, :reasons, keyword_init: true) do
    alias_method :success?, :success

    def initialize(success:, score: nil, errors: [], reasons: [])
      super
    end
  end

  def initialize(
    recaptcha_version: 3,
    recaptcha_action: nil,
    score_threshold: 0.0,
    analytics: nil,
    extra_analytics_properties: {}
  )
    if !VALID_RECAPTCHA_VERSIONS.include?(recaptcha_version)
      raise ArgumentError, "Invalid reCAPTCHA version #{recaptcha_version}, expected one of " \
                           "#{VALID_RECAPTCHA_VERSIONS}"
    end

    @score_threshold = score_threshold
    @analytics = analytics
    @recaptcha_version = recaptcha_version
    @recaptcha_action = recaptcha_action
    @extra_analytics_properties = extra_analytics_properties
  end

  def exempt?
    !score_threshold.positive?
  end

  def valid?(recaptcha_token)
    return true if exempt?
    return false if recaptcha_token.blank?
    result = recaptcha_result(recaptcha_token)
    log_analytics(result:)
    recaptcha_result_valid?(result)
  rescue Faraday::Error => error
    log_analytics(error:)
    true
  end

  private

  def recaptcha_result(recaptcha_token)
    response = faraday.post(
      VERIFICATION_ENDPOINT,
      URI.encode_www_form(secret: recaptcha_secret_key, response: recaptcha_token),
    ) do |request|
      request.options.context = { service_name: 'recaptcha' }
    end

    success, score, error_codes = response.body.values_at('success', 'score', 'error-codes')
    errors, reasons = error_codes.to_a.partition { |error_code| is_result_error?(error_code) }
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

    if result.success?
      recaptcha_score_meets_threshold?(result.score)
    else
      result.errors.present?
    end
  end

  def recaptcha_score_meets_threshold?(score)
    case recaptcha_version
    when 2
      true
    when 3
      score >= score_threshold
    end
  end

  def is_result_error?(error_code)
    RESULT_ERRORS.include?(error_code)
  end

  def log_analytics(result: nil, error: nil)
    analytics&.recaptcha_verify_result_received(
      recaptcha_result: result.to_h.presence,
      score_threshold:,
      recaptcha_version:,
      evaluated_as_valid: recaptcha_result_valid?(result),
      exception_class: error&.class&.name,
      validator_class: self.class.name,
      **extra_analytics_properties,
    )
  end

  def recaptcha_secret_key
    case recaptcha_version
    when 2
      IdentityConfig.store.recaptcha_secret_key_v2
    when 3
      IdentityConfig.store.recaptcha_secret_key_v3
    end
  end
end
