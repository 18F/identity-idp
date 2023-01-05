class SessionRedisDownErrorHandler
  def self.call(error, _env, _sid)
    raise error
  end
end
