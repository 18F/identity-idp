class FakeVoiceCall
  HttpClient = Struct.new(:adapter)

  cattr_accessor :calls
  self.calls = []

  def initialize(_account_sid, _auth_token); end

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
