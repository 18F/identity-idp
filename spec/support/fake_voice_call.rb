class FakeVoiceCall
  Call = Struct.new(:from, :to, :url)

  cattr_accessor :calls
  self.calls = []

  def initialize(_account_sid, _auth_token); end

  def calls
    self
  end

  def create(opts = {})
    self.class.calls << Call.new(opts[:from], opts[:to], opts[:url])
  end
end
