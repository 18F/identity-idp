class NullTwilioClient
  def messages
    self
  end

  def calls
    self
  end

  def create(_params)
    # noop
  end
end
