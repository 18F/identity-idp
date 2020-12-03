class SessionEncryptorErrorHandler
  def self.call(error, _sid)
    raise error
  end
end
