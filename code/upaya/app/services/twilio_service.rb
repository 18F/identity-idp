class TwilioService
  # https://www.twilio.com/docs/api/rest/test-credentials#test-incoming-phone-numbers-parameters-PhoneNumber
  TWILIO_TEST_NUMBER = '+15005550006'

  def initialize
    return twilio_test_client if FeatureManagement.pt_mode?
    return twilio_proxy_client if proxy_addr.present?
    twilio_client
  end

  def proxy_addr
    Figaro.env.proxy_addr
  end

  def proxy_port
    Figaro.env.proxy_port
  end

  def account
    @account ||= self.class.random_account
  end

  def twilio_proxy_client
    @client ||= Twilio::REST::Client.new(
      account['sid'],
      account['auth_token'],
      proxy_addr: proxy_addr,
      proxy_port: proxy_port
    )
  end

  def twilio_test_client
    @client ||= Twilio::REST::Client.new(
      Figaro.env.twilio_test_account_sid,
      Figaro.env.twilio_test_auth_token
    )
  end

  def twilio_client
    @client ||= Twilio::REST::Client.new(
      account['sid'],
      account['auth_token']
    )
  end

  def send_sms(params = {})
    params = params.reverse_merge(from: from_number)
    @client.messages.create(params)
  end

  def from_number
    return TWILIO_TEST_NUMBER if FeatureManagement.pt_mode?
    "+1#{account['number']}"
  end

  def self.singular_account
    Rails.logger.warn('Please set up the `twilio_accounts` entry in config/secrets.yml')
    {
      'sid' => Figaro.env.twilio_account_sid,
      'auth_token' => Figaro.env.twilio_auth_token,
      'number' => Figaro.env.twilio_number
    }
  end

  def self.accounts
    Rails.application.secrets.twilio_accounts || [singular_account]
  end

  def self.random_account
    accounts.sample
  end
end
