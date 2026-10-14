# frozen_string_literal: true

module AccountRecovery
  # Creates an account-preserving MFA recovery request for a user who has
  # authenticated with their password but cannot access any configured MFA
  # method.
  #
  # Phase 1 scope (docs/adr/0001-account-preserving-mfa-recovery.md): this
  # persists the request, moves it into the waiting state, and notifies the
  # last sign-in email address. Recovery token issuance and MFA replacement
  # happen in later phases.
  #
  # Phase 1 *rejects* a user who already has an in-flight request in either
  # workflow rather than superseding it. The ADR's atomic supersession behavior
  # arrives with the cancellation and grant work in a later phase, so until then
  # the safer behavior is to refuse to start a second request.
  class CreateRequest
    REQUEST_NOT_PERSISTED = :request_not_persisted

    # The created record, available to callers after a successful #call.
    # @return [AccountRecoveryRequest, nil]
    attr_reader :account_recovery_request

    # @param user [User]
    # @param requesting_issuer [String, nil]
    def initialize(user:, requesting_issuer:)
      @user = user
      @requesting_issuer = requesting_issuer
    end

    # @return [FormResponse]
    def call
      # Eligibility is re-checked here rather than trusted from the page that
      # rendered the link.
      eligibility = EligibilityPolicy.new(user: user).call

      return failure(eligibility.reason) if !eligibility.eligible?

      @account_recovery_request = create_request

      return failure(REQUEST_NOT_PERSISTED) if account_recovery_request.blank?

      notify_user_by_email

      FormResponse.new(
        success: true,
        extra: {
          eligibility_reason: eligibility.reason,
          flow_variant: account_recovery_request.flow_variant,
          recovery_state: account_recovery_request.state,
        },
      )
    end

    private

    attr_reader :user, :requesting_issuer

    def notify_user_by_email
      UserMailer.with(user: user, email_address: user.last_sign_in_email_address)
        .account_recovery_request.deliver_now_or_later
    end

    # @param reason [Symbol] bounded, non-PII reason safe for analytics
    # @return [FormResponse]
    def failure(reason)
      FormResponse.new(
        success: false,
        errors: { base: [reason.to_s] },
        extra: { eligibility_reason: reason },
      )
    end

    # Creates the new request under a user lock so two concurrent submissions
    # cannot both win. The partial unique index on active requests is the
    # authoritative guard; a loser in that race fails closed rather than raising.
    # @return [AccountRecoveryRequest, nil]
    def create_request
      user.with_lock do
        request = AccountRecoveryRequest.create!(
          user: user,
          flow_variant: AccountRecoveryRequest::FLOW_VARIANT_ACCOUNT_PRESERVING,
          state: AccountRecoveryRequest::REQUESTED,
          requested_at: Time.zone.now,
          requesting_issuer: requesting_issuer,
        )

        # A request that cannot reach the waiting state is not usable, so fail
        # closed rather than leaving a stranded row behind.
        raise ActiveRecord::Rollback if !request.wait!

        request
      end
    rescue ActiveRecord::RecordNotUnique
      # Another request for this user became active between the eligibility
      # check and the insert.
      nil
    end
  end
end
