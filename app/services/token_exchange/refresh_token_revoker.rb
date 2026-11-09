# frozen_string_literal: true

module TokenExchange
  # Ends a person's refresh token families when something outside the actor means it should no
  # longer get subject tokens on their behalf. The actor's own sign-out uses the revocation
  # endpoint instead.
  module RefreshTokenRevoker
    # Security events after which no actor should keep acting for the person without a new
    # sign-in. Account reinstatement, email changes and reproofing aren't among them.
    REVOKING_SECURITY_EVENTS = [
      PushNotification::AccountDisabledEvent,
      PushNotification::AccountPurgedEvent,
      PushNotification::IdentifierRecycledEvent,
      PushNotification::MfaLimitAccountLockedEvent,
      PushNotification::PasswordResetEvent,
      PushNotification::RecoveryActivatedEvent,
      PushNotification::RecoveryInformationChangedEvent,
    ].freeze

    module_function

    # @param event [Object] a PushNotification event
    def revoke_for_security_event(event)
      return unless REVOKING_SECURITY_EVENTS.include?(event.class)
      return if event.user.blank?

      revoke(TokenExchangeRefreshToken.where(user_id: event.user.id), reason: 'security_event')
    end

    # The person disconnected the actor from their account.
    def revoke_for_actor(user_id:, actor_issuer:)
      revoke(
        TokenExchangeRefreshToken.where(user_id:, actor_issuer:),
        reason: 'service_provider_disconnected',
      )
    end

    # The person revoked delegation consent for a target, so families whose sign-in named one of
    # that target's resources can no longer be refreshed.
    def revoke_for_target(user:, target_app:)
      resources = IdentityConfig.store.token_exchange_allowed_targets
        .select { |allowed| allowed[:issuer] == target_app }
        .pluck(:resource)
      return 0 if resources.empty?

      revoke(
        TokenExchangeRefreshToken.where(user_id: user.id, resource: resources),
        reason: 'consent_revoked',
      )
    end

    def revoke(scope, reason:)
      families = scope.unrevoked.distinct.pluck(:family_id)
      return 0 if families.empty?

      TokenExchangeRefreshToken.revoke_families!(families, reason:)
    end
    private_class_method :revoke
  end
end
