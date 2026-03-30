class FakeRequest
  attr_reader :headers
  attr_reader :referer

  def initialize(headers: {}, referer: nil)
    @headers = headers
    @referer = referer
  end

  def ip
    '127.0.0.1'
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
