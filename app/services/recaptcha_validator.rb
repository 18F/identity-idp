class RecaptchaValidator
  class ValidationError < StandardError; end

  attr_reader :score_threshold

  def initialize(score_threshold: 0.0)
    @score_threshold = score_threshold
  end

  def exempt?
    !score_threshold.positive?
  end

  def valid?(recaptcha_token)
    return true if exempt?

    response = faraday.post(
      VERIFICATION_ENDPOINT,
      URI.encode_www_form(
        secret: IdentityConfig.store.recaptcha_secret_key,
        response: recaptcha_token,
      ),
    )

    if !response.body['success']
      raise ValidationError.new("reCAPTCHA validation error: #{response.body['error-codes']}")
    end

    response.body['score'] >= score_threshold
  rescue Faraday::Error, ValidationError => error
    NewRelic::Agent.notice_error(error)
    true
  end

  private

  def faraday
    Faraday.new do |conn|
      conn.request :instrumentation, name: 'request_log.faraday'
      conn.response :json
    end
  end

  VERIFICATION_ENDPOINT = 'https://www.google.com/recaptcha/api/siteverify'.freeze
end
