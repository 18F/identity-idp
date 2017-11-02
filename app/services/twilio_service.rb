class TwilioService
  SMS_ERROR_CODE = 21_211
  INVALID_ERROR_CODE = 21_614

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
      params = params.reverse_merge(from: from_number)
      client.messages.create(params)
    end
  end

  def account
    @account ||= random_account
  end

  def from_number
    "+1#{account['number']}"
  end

  private

  attr_reader :client

  def twilio_client
    telephony_service.new(
      account['sid'],
      account['auth_token']
    )
  end

  def random_account
    TWILIO_ACCOUNTS.sample
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
