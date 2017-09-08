class TwilioService
  cattr_accessor :telephony_service do
    Twilio::REST::Client
  end

  def initialize
    @client = if FeatureManagement.telephony_disabled?
                NullTwilioClient.new
              elsif proxy_addr.present?
                twilio_proxy_client
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

  def proxy_addr
    Figaro.env.proxy_addr
  end

  def proxy_port
    Figaro.env.proxy_port
  end

  def twilio_proxy_client
    telephony_service.new(
      account['sid'],
      account['auth_token'],
      proxy_addr: proxy_addr,
      proxy_port: proxy_port
    )
  end

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

  def sanitize_phone_number(str)
    str.gsub!(/\+[\d\(\)\- ]+/) { |match| match.gsub(/\d/, '#') }
  end
end
