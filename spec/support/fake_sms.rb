class FakeSms
  Message = Struct.new(:to, :body, :messaging_service_sid)

  cattr_accessor :messages
  self.messages = []

  def initialize(_account_sid, _auth_token); end

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
end
