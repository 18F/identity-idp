class PhoneVerification
  AUTHY_HOST = 'https://api.authy.com'.freeze
  AUTHY_VERIFY_ENDPOINT = '/protected/json/phones/verification/start'.freeze

  TIMEOUT = Figaro.env.twilio_timeout.to_i

  AVAILABLE_LOCALES = %w[af ar ca zh zh-CN zh-HK hr cs da nl en fi fr de el he hi hu id it ja ko ms
                         nb pl pt-BR pt ro ru es sv tl th tr vi].freeze

  cattr_accessor :adapter do
    Faraday.new(url: AUTHY_HOST, request: { open_timeout: TIMEOUT, timeout: TIMEOUT }) do |faraday|
      faraday.adapter :typhoeus
    end
  end

  def initialize(phone:, code:, locale: nil)
    @phone = phone
    @code = code
    @locale = locale
  end

  def send_sms
    tries ||= 2
    raise_bad_request_error unless response.success?
  rescue Faraday::TimeoutError, Faraday::ConnectionFailed => exception
    retry unless (tries -= 1).zero?
    raise_connection_timed_out_or_failed_error(exception)
  end

  private

  attr_reader :phone, :code, :locale, :connection

  def response
    @response ||= begin
      adapter.post do |request|
        request.url AUTHY_VERIFY_ENDPOINT
        request.headers['X-Authy-API-Key'] = Figaro.env.twilio_verify_api_key
        request.body = request_body
      end
    end
  end

  def request_body
    {
      code_length: 6,
      country_code: country_code,
      custom_code: code,
      locale: locale,
      phone_number: number_without_country_code,
      via: 'sms',
    }
  end

  def country_code
    parsed_phone.country_code
  end

  def number_without_country_code
    parsed_phone.raw_national
  end

  def parsed_phone
    @parsed_phone ||= Phonelib.parse(phone)
  end

  def raise_bad_request_error
    raise VerifyError.new(
      code: error_code,
      message: error_message,
      status: response.status,
      response: response.body
    )
  end

  def raise_connection_timed_out_or_failed_error(exception)
    raise VerifyError.new(
      code: 4_815_162_342,
      message: "Twilio Verify: #{exception.class}",
      status: 0,
      response: ''
    )
  end

  def error_code
    response_body.fetch('error_code', nil).to_i
  end

  def error_message
    response_body.fetch('message', '')
  end

  def response_body
    @response_body ||= JSON.parse(response.body)
  rescue JSON::ParserError
    {}
  end

  class VerifyError < StandardError
    attr_reader :code, :message, :status, :response

    def initialize(code:, message:, status:, response:)
      @code = code
      @message = message
      @status = status
      @response = response
    end
  end
end
