class SessionSyncer
  def initialize(session_store)
    self.session_store = session_store
  end

  def clean(user)
    user.sessions.pluck(:session_id).each do |session_id|
      destroy_if_not_in_redis(session_id)
    end
  end

  private

  attr_accessor :session_store

  def destroy_if_not_in_redis(session_id)
    return if session_key_exists?(session_id)
    Session.where(session_id: session_id).destroy_all
  end

  def session_key_exists?(session_id)
    redis.exists(session_key_name(session_id))
  end

  def session_key_name(session_id)
    session_store.send(:prefixed, session_id)
  end

  def redis
    session_store.send(:redis)
  end
end
