class NullTwilioClient
  def messages
    self
  end

  def create(params = {})
    # noop
  end
end
