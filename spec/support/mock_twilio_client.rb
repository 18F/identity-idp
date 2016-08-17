class MockTwilioClient
  Message = Struct.new(:from, :to, :body, :url)
  Call = Struct.new(:from, :to, :body, :url)

  cattr_accessor :messages
  cattr_accessor :calls
  self.messages = []
  self.calls = []

  def initialize(_account_sid, _auth_token)
  end

  def messages
    @type = :messages
    self
  end

  def calls
    @type = :calls
    self
  end

  # rubocop:disable all
  # a metaprogramming method designed to capture #create calls
  # for the Twilio::REST::Client and place the newly created struct
  # in an array for verification
  def create(from:, to:, body: nil, url: nil)
    cmd = "#{@type.to_s.capitalize.singularize}.new(
      from,
      to,
      body,
      url)"
    item = eval(cmd)
    self.class.send(@type.to_s) << item
  end
  # rubocop:enable all
end
