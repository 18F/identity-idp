# frozen_string_literal: true

module TokenExchange
  # Issues the refresh tokens an actor trades for new subject tokens: the first one, which starts
  # a family when a token exchange authorization code is redeemed, and each rotated one after.
  # The raw token is returned once and never stored; the database keeps only its digest.
  class RefreshTokenIssuer
    IssuedToken = Struct.new(:token, :record, keyword_init: true)

    # Starts a family for a subject token just issued from an authorization code.
    # @param identity [ServiceProviderIdentity] the actor's identity for the person
    # @param resource [String, nil] the resource the sign-in named, which every subject token in
    #   the family can be exchanged for
    # @param dpop_jkt [String] RFC 7638 thumbprint the subject token is bound to; refresh tokens
    #   are only issued for key-bound subject tokens
    # @param authenticated_at [Time] when the person last authenticated; the family's absolute
    #   lifetime counts from here
    # @return [IssuedToken]
    def self.issue(identity:, actor_return_log_id:, resource:, dpop_jkt:, authenticated_at:,
                   now: Time.zone.now)
      family_expires_at = authenticated_at + max_lifetime

      create(
        now:,
        family_expires_at:,
        attributes: {
          family_id: SecureRandom.uuid,
          user_id: identity.user_id,
          actor_issuer: identity.service_provider,
          identity_uuid: identity.uuid,
          scope: identity.scope,
          ial: identity.ial,
          actor_return_log_id:,
          resource:,
          dpop_jkt:,
          authenticated_at:,
          family_expires_at:,
        },
      )
    end

    # Marks the presented refresh token used and issues the next one in its family. Marking is a
    # conditional update, so of two requests racing with the same token only one gets a new
    # token; the other is treated like any reuse.
    # @param previous [TokenExchangeRefreshToken]
    # @return [IssuedToken, nil] nil when the token was already used or revoked
    def self.rotate(previous, now: Time.zone.now)
      TokenExchangeRefreshToken.transaction do
        # rubocop:disable Rails/SkipsModelValidations
        marked = TokenExchangeRefreshToken
          .where(id: previous.id, used_at: nil, revoked_at: nil)
          .update_all(used_at: now, updated_at: now)
        # rubocop:enable Rails/SkipsModelValidations
        next if marked != 1

        create(
          now:,
          family_expires_at: previous.family_expires_at,
          attributes: previous.attributes.slice(
            'family_id', 'user_id', 'actor_issuer', 'identity_uuid', 'scope', 'ial',
            'actor_return_log_id', 'resource', 'dpop_jkt', 'authenticated_at',
            'family_expires_at'
          ),
        )
      end
    end

    def self.create(now:, family_expires_at:, attributes:)
      token = SecureRandom.urlsafe_base64(32)
      record = TokenExchangeRefreshToken.create!(
        **attributes.symbolize_keys,
        token_digest: TokenExchangeRefreshToken.digest(token),
        expires_at: [now + idle_timeout, family_expires_at].min,
      )

      IssuedToken.new(token:, record:)
    end
    private_class_method :create

    def self.idle_timeout
      IdentityConfig.store.token_exchange_refresh_token_idle_timeout_in_minutes.minutes
    end

    def self.max_lifetime
      IdentityConfig.store.token_exchange_refresh_token_max_lifetime_in_minutes.minutes
    end
  end
end
