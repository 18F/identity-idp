class RecaptchaValidator
  VERIFICATION_ENDPOINT = 'https://www.google.com/recaptcha/api/siteverify'.freeze

  EXEMPT_ERROR_CODES = ['missing-input-secret', 'invalid-input-secret']

  class ValidationError < StandardError; end

  attr_reader :score_threshold, :analytics

  def initialize(score_threshold: 0.0, analytics: nil)
    @score_threshold = score_threshold
    @analytics = analytics
  end

  def exempt?
    !score_threshold.positive?
  end

  def valid?(recaptcha_token)
    return true if exempt?
    return false if recaptcha_token.blank?

    response = faraday.post(
      VERIFICATION_ENDPOINT,
      URI.encode_www_form(
        secret: IdentityConfig.store.recaptcha_secret_key,
        response: recaptcha_token,
      ),
    ) do |request|
      request.options.context = { service_name: 'recaptcha' }
    end

    log_analytics(recaptcha_result: response&.body)
    recaptcha_result_valid?(response.body)
  rescue Faraday::Error => error
    log_analytics(error:)
    true
  end

  private

  def faraday
    Faraday.new do |conn|
      conn.request :instrumentation, name: 'request_log.faraday'
      conn.response :json
    end
  end

  def recaptcha_result_valid?(recaptcha_result)
    if recaptcha_result.blank?
      true
    elsif recaptcha_result['success']
      recaptcha_result['score'] >= score_threshold
    else
      (recaptcha_result['error-codes'] - EXEMPT_ERROR_CODES).blank?
    end
  end

  def log_analytics(recaptcha_result: nil, error: nil)
    analytics&.recaptcha_verify_result_received(
      recaptcha_result:,
      score_threshold:,
      evaluated_as_valid: recaptcha_result_valid?(recaptcha_result),
      exception_class: error&.class&.name,
    )
  end
end
