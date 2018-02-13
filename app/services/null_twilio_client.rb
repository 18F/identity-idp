class NullTwilioClient
  HttpClient = Struct.new(:adapter)

  def messages
    self
  end

  def calls
    self
  end

  def create(_params)
    # noop
  end

  def http_client
    HttpClient.new(adapter: 'foo')
  end
end
