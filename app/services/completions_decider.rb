class CompletionsDecider
  def initialize(user_agent:, request_url:)
    @user_agent = user_agent
    @request_url = request_url
  end

  def go_back_to_mobile_app?
    return false if redirect_uri.blank?
    desktop_and_app_redirect_uri?
  end

  private

  attr_reader :user_agent, :request_url

  def desktop_and_app_redirect_uri?
    client.device_type == 'desktop' && !redirect_uri.start_with?('http')
  end

  def client
    @client ||= DeviceDetector.new(user_agent)
  end

  def redirect_uri
    @redirect_uri ||= UriService.params(request_url)[:redirect_uri]
  end
end
