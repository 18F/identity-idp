class PhoneVerification
  AUTHY_START_ENDPOINT = 'https://api.authy.com/protected/json/phones/verification/start'.freeze

  HEADERS = { 'X-Authy-API-Key' => Figaro.env.twilio_verify_api_key }.freeze
  OPEN_TIMEOUT = 5
  READ_TIMEOUT = 5

  AVAILABLE_LOCALES = %w[af ar ca zh zh-CN zh-HK hr cs da nl en fi fr de el he hi hu id it ja ko ms
                         nb pl pt-BR pt ro ru es sv tl th tr vi].freeze

  cattr_accessor :adapter do
    Typhoeus
  end

  def initialize(phone:, code:, locale: nil)
    @phone = phone
    @code = code
    @locale = locale
  end

  # rubocop:disable Style/GuardClause
  def send_sms
    unless start_request.success?
      raise VerifyError.new(
        code: error_code,
        message: error_message,
        status: start_request.response_code,
        response: start_request.response_body
      )
    end
  end
  # rubocop:enable Style/GuardClause

  private

  attr_reader :phone, :code, :locale

  def error_code
    response_body.fetch('error_code', nil).to_i
  end

  def error_message
    response_body.fetch('message', '')
  end

  def response_body
    @response_body ||= JSON.parse(start_request.response_body)
  rescue JSON::ParserError
    {}
  end

  def start_request
    @start_request ||= adapter.post(AUTHY_START_ENDPOINT, start_params)
  end

  # rubocop:disable Metrics/MethodLength
  def start_params
    {
      headers: HEADERS,
      body: {
        code_length: 6,
        country_code: country_code,
        custom_code: code,
        locale: locale,
        phone_number: number_without_country_code,
        via: 'sms',
      },
      connecttimeout: OPEN_TIMEOUT,
      timeout: READ_TIMEOUT,
    }
  end
  # rubocop:enable Metrics/MethodLength

  def number_without_country_code
    parsed_phone.raw_national
  end

  def parsed_phone
    @parsed_phone ||= Phonelib.parse(phone)
  end

  def country_code
    parsed_phone.country_code
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
