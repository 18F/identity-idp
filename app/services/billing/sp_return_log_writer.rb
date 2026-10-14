# frozen_string_literal: true

module Billing
  # The one place an `sp_return_logs` row is written, for both the direct handoff of a sign-in to
  # a service provider (BillableEventTrackable) and the exchange that issues a delegated token for
  # an agency API (DelegatedReturnRecorder). Both go through here so the columns invoicing depends
  # on (`ial`, `billable`, `returned_at`, the profile columns) are computed one way.
  #
  # `request_id` is unique. The direct path reuses the service provider request id and relies on
  # the unique index to drop a repeat row silently. The delegated path uses one deterministic id
  # per approval, billing issuer and IAL, so the first exchange under an approval is the billable
  # row and later exchanges are kept as a non-billable trail: with `retry_on_collision: true` a
  # collision is retried once with a random id and `billable: false`.
  #
  # The insert runs in a savepoint so a unique-index collision never aborts a transaction the
  # caller holds open around it (the exchange writes its token record in one).
  class SpReturnLogWriter
    # @param user [User]
    # @param issuer [String] issuer whose partner agreement is invoiced for the row
    # @param ial [Integer] 1 or 2 as invoicing expects (IalContext#bill_for_ial_1_or_2), never
    #   the raw stored IAL
    # @param request_id [String]
    # @param billable [Boolean]
    # @param access_type [String] SpReturnLog::ACCESS_TYPE_DIRECT or ACCESS_TYPE_DELEGATED
    # @param retry_on_collision [Boolean] write a non-billable trail row with a random id when
    #   `request_id` already exists
    # @return [SpReturnLog, nil] the row, or nil when it already existed and no retry was asked
    def self.write(
      user:, issuer:, ial:, request_id:, billable:,
      access_type: SpReturnLog::ACCESS_TYPE_DIRECT, retry_on_collision: false
    )
      profile = user.active_profile if ial > 1
      SpReturnLog.transaction(requires_new: true) do
        SpReturnLog.create(
          request_id:,
          user:,
          billable:,
          ial:,
          issuer:,
          profile_id: profile&.id,
          profile_verified_at: profile&.verified_at,
          profile_requested_issuer: profile&.initiating_service_provider_issuer,
          returned_at: Time.zone.now,
          access_type:,
        )
      end
    rescue ActiveRecord::RecordNotUnique
      return nil unless retry_on_collision && billable

      write(
        user:, issuer:, ial:, request_id: SecureRandom.uuid, billable: false,
        access_type:, retry_on_collision: false
      )
    end
  end
end
