class FakeRequest
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

  def cookies
    'fake_cookies'
  end
end
