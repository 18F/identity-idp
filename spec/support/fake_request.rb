class FakeRequest
  attr_accessor :cookies

  def initialize(cookies = {test:'fake_cookies'})
    @cookies = cookies
  end

  def remote_ip
    '127.0.0.1'
  end

  def user_agent
    'special_agent'
  end

  def host
    'fake_host'
  end

  def headers
    'fake_headers'
  end
end
