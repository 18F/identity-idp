# frozen_string_literal: true

# The live delegated tokens, kept in Redis.
#
# A delegated token is an opaque random string. Its meaning lives here: an entry keyed by the
# SHA-256 digest of the token string, holding what introspection reports (audience, scope,
# delegation id, forwarded assurance levels, key binding) and the id of the issuance record in
# Postgres. The entry's TTL is the token's lifetime, so an expired token vanishes on its own and
# an absent entry means "not active". The token string itself is never stored.
#
# Two index sets make revocation a cascade rather than a scan: `delegated_tokens:grant:<id>`
# lists the digests of every live token issued under one approval, and
# `delegated_tokens:family:<id>` lists those of one refresh family. Revoking a grant or a family
# deletes every listed entry and the set.
class DelegatedTokenStore
  TOKEN_KEY_PREFIX = 'delegated_token:'
  GRANT_INDEX_PREFIX = 'delegated_tokens:grant:'
  FAMILY_INDEX_PREFIX = 'delegated_tokens:family:'

  # @param token [String] the token string as handed to the service provider
  # @return [String] hex SHA-256 digest; the Redis key suffix and the token's `jti`
  def self.digest(token)
    DelegatedAccess::OpaqueToken.digest(token)
  end

  # Stores the live entry for a freshly issued token and lists it in the grant and family
  # index sets.
  #
  # @param token [String] the token string
  # @param attributes [Hash] what introspection reports; must include +grant_id+ and
  #   +refresh_family_id+ so the token can be found for revocation
  # @param ttl [Integer] seconds until the token expires
  def self.write(token, attributes, ttl:)
    attributes = attributes.symbolize_keys
    grant_id = attributes.fetch(:grant_id)
    family_id = attributes.fetch(:refresh_family_id)
    digest = digest(token)

    REDIS_POOL.with do |client|
      client.multi do |multi|
        multi.set(TOKEN_KEY_PREFIX + digest, attributes.to_json, ex: ttl)
        multi.sadd(GRANT_INDEX_PREFIX + grant_id.to_s, digest)
        multi.sadd(FAMILY_INDEX_PREFIX + family_id.to_s, digest)
      end
      # An index set must outlive every token it lists, so its TTL only ever grows: a new token
      # with a shorter remaining lifetime than the set's must not shorten the set.
      [GRANT_INDEX_PREFIX + grant_id.to_s, FAMILY_INDEX_PREFIX + family_id.to_s].each do |key|
        client.expire(key, ttl) if client.ttl(key) < ttl
      end
    end
  end

  # @param token [String] the token string as presented by a caller
  # @return [Hash{Symbol => Object}, nil] the stored attributes, or nil when the token is not
  #   active (never issued, expired or revoked)
  def self.read(token)
    return nil if token.blank?

    raw = REDIS_POOL.with { |client| client.get(TOKEN_KEY_PREFIX + digest(token)) }
    return nil if raw.nil?

    JSON.parse(raw, symbolize_names: true)
  end

  # Removes one live token: its entry and its listing in both index sets. The sets are left in
  # place for the other tokens they list.
  # @param token [String] the token string as presented by a caller
  # @return [Boolean] whether a live entry was removed
  def self.revoke_token(token)
    attributes = read(token)
    return false if attributes.nil?

    digest = digest(token)
    REDIS_POOL.with do |client|
      client.multi do |multi|
        multi.del(TOKEN_KEY_PREFIX + digest)
        multi.srem(GRANT_INDEX_PREFIX + attributes[:grant_id].to_s, digest)
        multi.srem(FAMILY_INDEX_PREFIX + attributes[:refresh_family_id].to_s, digest)
      end
    end
    true
  end

  # Removes every live token issued under one approval.
  # @return [Integer] how many token entries were removed
  def self.revoke_grant(grant_id)
    revoke_index(GRANT_INDEX_PREFIX + grant_id.to_s)
  end

  # Re-points every live token of one approval at another approval: each listed entry's
  # `grant_id` is rewritten (keeping its remaining lifetime) and the digests move to the new
  # approval's index set, which keeps the longer of the two lifetimes. Used when a re-approval
  # replaces an earlier approval of the same application.
  # @return [Integer] how many token entries were moved
  def self.move_grant(from_grant_id, to_grant_id)
    from_key = GRANT_INDEX_PREFIX + from_grant_id.to_s
    to_key = GRANT_INDEX_PREFIX + to_grant_id.to_s
    REDIS_POOL.with do |client|
      digests = client.smembers(from_key)
      moved = 0
      digests.each do |digest|
        token_key = TOKEN_KEY_PREFIX + digest
        raw = client.get(token_key)
        remaining = client.ttl(token_key)
        # An entry that expired since it was listed is skipped; it will not be found anyway.
        next if raw.nil? || remaining <= 0

        attributes = JSON.parse(raw, symbolize_names: true).merge(grant_id: to_grant_id)
        client.multi do |multi|
          multi.set(token_key, attributes.to_json, ex: remaining)
          multi.sadd(to_key, digest)
        end
        client.expire(to_key, remaining) if client.ttl(to_key) < remaining
        moved += 1
      end
      client.del(from_key)
      moved
    end
  end

  # Removes every live token of one refresh family.
  # @return [Integer] how many token entries were removed
  def self.revoke_family(family_id)
    revoke_index(FAMILY_INDEX_PREFIX + family_id.to_s)
  end

  # Deletes the token entries an index set lists, then the set itself. Entries that already
  # expired are simply absent; the count reflects entries actually removed.
  def self.revoke_index(index_key)
    REDIS_POOL.with do |client|
      digests = client.smembers(index_key)
      removed = digests.empty? ? 0 : client.del(*digests.map { |d| TOKEN_KEY_PREFIX + d })
      client.del(index_key)
      removed
    end
  end
  private_class_method :revoke_index
end
