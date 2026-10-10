# frozen_string_literal: true

module DelegatedAccess
  # The opaque strings delegated access hands out and later looks up: access tokens, refresh
  # tokens and the sign-in waiver link. Each is random, carries no claims, and is stored only as
  # its digest, so a copy of the store reveals nothing a caller could present.
  module OpaqueToken
    # 32 random bytes as base64url without padding: 43 characters, 256 bits of entropy.
    # @return [String]
    def self.generate
      SecureRandom.urlsafe_base64(32)
    end

    # The hex SHA-256 of a token string: the key it is stored and found under.
    # @param token [String, nil] the string exactly as handed out or presented
    # @return [String]
    def self.digest(token)
      Digest::SHA256.hexdigest(token.to_s)
    end
  end
end
