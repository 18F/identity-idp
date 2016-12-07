class FakeVoiceCall
  cattr_accessor :calls
  self.calls = []

  def initialize(_account_sid, _auth_token); end

  def calls
    self
  end

  def create(opts = {})
    self.class.calls << OpenStruct.new(opts)
  end
end
