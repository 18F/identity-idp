class FakeRequest
  attr_reader :headers

  def initialize(headers: {})
    @headers = headers
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

  def cookies
    'fake_cookies'
  end

  def path
    'fake_path'
  end

  def env
    { 'REQUEST_METHOD' => 'GET' }
  end
end
