# frozen_string_literal: true

# The key a sign-in access token is bound to (RFC 9449), kept encrypted in Redis under the token's
# digest for exactly the token's lifetime. The user-information and document-image endpoints read it
# to require a proof from that key, so a copied token is useless without the key, and nothing about
# the key is written to the identity row: when the token expires, so does its binding. A bearer
# token has no record. The raw token is never stored.
AccessTokenBinding = Struct.new(:id, :dpop_jkt, keyword_init: true) do
  def self.redis_key_prefix
    'access-token-binding'
  end

  def self.load(access_token)
    EncryptedRedisStructStorage.load(digest(access_token), type: self)
  end

  def self.store(access_token:, dpop_jkt:, expires_in:)
    binding = new(id: digest(access_token), dpop_jkt:)
    EncryptedRedisStructStorage.store(binding, expires_in:)
  end

  def self.digest(access_token)
    Digest::SHA256.hexdigest(access_token.to_s)
  end
end
