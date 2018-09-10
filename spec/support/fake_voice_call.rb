class FakeVoiceCall
  HttpClient = Struct.new(:adapter)

  cattr_accessor :calls
  self.calls = []

  def initialize(_username, _password, _account_sid, _region, _http_client); end

  def calls
    self
  end

  def create(opts = {})
    self.class.calls << OpenStruct.new(opts)
  end

  def http_client
    HttpClient.new(adapter: 'foo')
  end
end
