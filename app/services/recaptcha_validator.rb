class RecaptchaValidator
  VERIFICATION_ENDPOINT = 'https://www.google.com/recaptcha/api/siteverify'.freeze
  EXEMPT_ERROR_CODES = ['missing-input-secret', 'invalid-input-secret']
  VALID_RECAPTCHA_VERSIONS = [2, 3]

  attr_reader :recaptcha_version, :score_threshold, :analytics, :extra_analytics_properties

  def initialize(
    recaptcha_version: 3,
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
    @extra_analytics_properties = extra_analytics_properties
  end

  def exempt?
    !score_threshold.positive?
  end

  def valid?(recaptcha_token)
    return true if exempt?
    return false if recaptcha_token.blank?
    response = recaptcha_response(recaptcha_token)
    log_analytics(recaptcha_result: response&.body)
    recaptcha_result_valid?(response.body)
  rescue Faraday::Error => error
    log_analytics(error:)
    true
  end

  private

  def recaptcha_response(recaptcha_token)
    faraday.post(
      VERIFICATION_ENDPOINT,
      URI.encode_www_form(secret: recaptcha_secret_key, response: recaptcha_token),
    ) do |request|
      request.options.context = { service_name: 'recaptcha' }
    end
  end

  def faraday
    Faraday.new do |conn|
      conn.request :instrumentation, name: 'request_log.faraday'
      conn.response :json
    end
  end

  def recaptcha_result_valid?(recaptcha_result)
    return true if recaptcha_result.blank?

    success, score, error_codes = recaptcha_result.values_at('success', 'score', 'error-codes')
    if success
      recaptcha_score_meets_threshold?(score)
    else
      recaptcha_errors_exempt?(error_codes)
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

  def recaptcha_errors_exempt?(error_codes)
    (error_codes - EXEMPT_ERROR_CODES).blank?
  end

  def log_analytics(recaptcha_result: nil, error: nil)
    analytics&.recaptcha_verify_result_received(
      recaptcha_result:,
      score_threshold:,
      recaptcha_version:,
      evaluated_as_valid: recaptcha_result_valid?(recaptcha_result),
      exception_class: error&.class&.name,
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
