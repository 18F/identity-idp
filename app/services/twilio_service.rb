class TwilioService
  attr_reader :client

  def initialize
    @client = if FeatureManagement.telephony_disabled?
                NullTwilioClient.new
              elsif proxy_addr.present?
                twilio_proxy_client
              else
                twilio_client
              end
  end

  def account
    @account ||= random_account
  end

  def from_number
    "+1#{account['number']}"
  end

  private

  def proxy_addr
    Figaro.env.proxy_addr
  end

  def proxy_port
    Figaro.env.proxy_port
  end

  def twilio_proxy_client
    Twilio::REST::Client.new(
      account['sid'],
      account['auth_token'],
      proxy_addr: proxy_addr,
      proxy_port: proxy_port
    )
  end

  def twilio_client
    Twilio::REST::Client.new(
      account['sid'],
      account['auth_token']
    )
  end

  def random_account
    TWILIO_ACCOUNTS.sample
  end
end
