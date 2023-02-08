class RecaptchaValidator
  VERIFICATION_ENDPOINT = 'https://www.google.com/recaptcha/api/siteverify'.freeze

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

    log_analytics(response.body)

    if !response.body['success']
      raise ValidationError.new("reCAPTCHA validation error: #{response.body['error-codes']}")
    end

    response.body['score'] >= score_threshold
  rescue Faraday::Error, ValidationError
    true
  end

  private

  def faraday
    Faraday.new do |conn|
      conn.request :instrumentation, name: 'request_log.faraday'
      conn.response :json
    end
  end

  def log_analytics(recaptcha_result)
    analytics&.recaptcha_verify_result_received(recaptcha_result:, score_threshold:)
  end
end
