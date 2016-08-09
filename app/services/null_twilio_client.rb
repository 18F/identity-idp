class NullTwilioClient
  def messages
    self
  end

  def create(_params)
    # noop
  end
end
