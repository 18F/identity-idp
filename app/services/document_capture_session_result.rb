DocumentCaptureSessionResult = Struct.new(:id, :success, :pii, keyword_init: true) do
  include EncryptedRedisStructStorage

  configure_encrypted_redis_struct key_prefix: 'dcs:result'

  alias_method :success?, :success
end
