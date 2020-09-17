ProofingDocumentCaptureSessionResult = Struct.new(:id, :pii, :result, keyword_init: true) do
  include EncryptedRedisStructStorage

  configure_encrypted_redis_struct key_prefix: 'dcs-proofing:result'
end
