class FakeSms
  Message = Struct.new(:to, :body, :messaging_service_sid)
  HttpClient = Struct.new(:adapter, :last_request)
  LastRequest = Struct.new(:url, :params, :headers, :method)

  cattr_accessor :messages
  self.messages = []

  def initialize(_username, _password, _account_sid, _region, _http_client); end

  def messages
    self
  end

  def create(opts = {})
    self.class.messages << Message.new(
      opts[:to],
      opts[:body],
      opts[:messaging_service_sid]
    )
  end

  def http_client
    HttpClient.new('foo', LastRequest.new('foo', {}, {}, 'get'))
  end
end
