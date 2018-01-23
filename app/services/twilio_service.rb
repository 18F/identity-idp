class TwilioService
  INVALID_VOICE_NUMBER_ERROR_CODE = 13_224
  SMS_ERROR_CODE = 21_614
  INVALID_ERROR_CODE = 21_211
  INVALID_CALLING_AREA_ERROR_CODE = 21_215

  cattr_accessor :telephony_service do
    Twilio::REST::Client
  end

  def initialize
    @client = if FeatureManagement.telephony_disabled?
                NullTwilioClient.new
              else
                twilio_client
              end
  end

  def place_call(params = {})
    sanitize_errors do
      params = params.reverse_merge(from: from_number)
      client.calls.create(params)
    end
  end

  def send_sms(params = {})
    sanitize_errors do
      params = params.reverse_merge(messaging_service_sid: Figaro.env.twilio_messaging_service_sid)
      client.messages.create(params)
    end
  end

  def phone_number
    @phone_number ||= random_phone_number
  end

  def from_number
    "+1#{phone_number}"
  end

  private

  attr_reader :client

  def twilio_client
    telephony_service.new(
      TWILIO_SID,
      TWILIO_AUTH_TOKEN
    )
  end

  def random_phone_number
    TWILIO_NUMBERS.sample
  end

  def sanitize_errors
    yield
  rescue Twilio::REST::RestError => error
    sanitize_phone_number(error.message)
    raise
  end

  DIGITS_TO_PRESERVE = 5

  def sanitize_phone_number(str)
    str.gsub!(/\+[\d\(\)\- ]+/) do |match|
      digits_preserved = 0

      match.gsub(/\d/) do |chr|
        (digits_preserved += 1) <= DIGITS_TO_PRESERVE ? chr : '#'
      end
    end
  end
end
