class FakeSms
  Message = Struct.new(:from, :to, :body)

  cattr_accessor :messages
  self.messages = []

  def initialize(_account_sid, _auth_token); end

  def messages
    self
  end

  def create(opts = {})
    self.class.messages << Message.new(opts[:from], opts[:to], opts[:body])
  end
end
