# frozen_string_literal: true

module Billing
  # Billing for one delegated token issued at a token exchange. Runs inside the transaction that
  # writes the token's issuance record and never fails it: every write here is in a savepoint and
  # every error is reported and swallowed, because a token the service provider has been promised
  # must not be lost over how it is invoiced.
  #
  # Three things are recorded:
  #
  # 1. The agency's billing row: an `sp_return_logs` row under the API's billing issuer with
  #    `access_type = 'delegated'`, the IAL invoicing bills the person's sign-in at (2 for a
  #    verified person the service provider signed in at IAL2 or IALmax, else 1) and the profile
  #    columns as a direct row carries them. Its request id is deterministic per approval,
  #    billing issuer and IAL, so the first exchange under an approval is the billable row and a
  #    later exchange under the same approval leaves a non-billable trail row with a random id.
  #    Renewals of an issued token never come here and write nothing.
  # 2. A `delegated_token_issued` adjustment linking that row to the token's issuance record,
  #    through which reports reach the acting service provider, the API and whether the person
  #    verified identity during the sign-in. The row itself carries none of those.
  # 3. For a billable row, the waiver of the service provider's own sign-in: the sign-in's
  #    return-log row is found through SignInWaiverLink by the digest of the subject token, or,
  #    once that link has lapsed, from the database (#sign_in_row_from_database), and an
  #    `exclude_from_billing` adjustment is appended pointing at the sign-in row, the agency's row
  #    and the token. The agency receiving the token is billed for the sign-in, proofing included,
  #    and the service provider is not. The outcome is logged so use of the fallback is visible.
  class DelegatedReturnRecorder
    attr_reader :issued, :grant, :resource_server, :service_provider, :identity, :subject_token

    # @param issued [TokenExchangeToken] the issuance record just written
    # @param grant [TokenExchangeGrant] the approval the token was issued under
    # @param resource_server [TokenExchangeResourceServer] the API the token is for
    # @param service_provider [ServiceProvider] the service provider acting for the person
    # @param identity [ServiceProviderIdentity] the person's sign-in to the service provider
    # @param subject_token [String] the service provider's access token presented at exchange;
    #   used only to compute a digest, never stored
    def initialize(issued:, grant:, resource_server:, service_provider:, identity:, subject_token:)
      @issued = issued
      @grant = grant
      @resource_server = resource_server
      @service_provider = service_provider
      @identity = identity
      @subject_token = subject_token
    end

    # @return [SpReturnLog, nil] the delegated row written, or nil when nothing was recorded
    def call
      row = nil
      SpReturnLog.transaction(requires_new: true) do
        row = write_delegated_row
        if row&.persisted?
          link_token_to(row)
          waive_sign_in(row) if row.billable
        end
      end
      row
    rescue StandardError => error
      NewRelic::Agent.notice_error(error)
      nil
    end

    # The sign-in's billable row found without the cache link: the most recent billable direct
    # row for this person at this service provider written since the sign-in that issued the
    # subject token began (the identity's last authentication). The identity records one sign-in
    # at a time, so a person who signed in to the service provider more than once in the window
    # can be matched to the wrong row, and a row written before the identity was re-linked is
    # not found at all; the logged outcome makes both cases countable.
    # @return [SpReturnLog, nil]
    def sign_in_row_from_database
      since = identity.last_authenticated_at
      return nil if since.nil?

      SpReturnLog
        .where(user_id: identity.user_id, issuer: service_provider.issuer, billable: true)
        .where("COALESCE(access_type, 'direct') = ?", SpReturnLog::ACCESS_TYPE_DIRECT)
        .where(returned_at: since..)
        .order(returned_at: :desc)
        .first
    end

    private

    def billing_issuer
      resource_server.billing_issuer_value
    end

    # The IAL invoicing bills, computed as for the direct handoff of this sign-in: never the raw
    # stored IAL, which is 0 for an IALmax request.
    def billed_ial
      @billed_ial ||= IalContext.new(
        ial: identity.ial, service_provider:, user: identity.user,
      ).bill_for_ial_1_or_2
    end

    def write_delegated_row
      SpReturnLogWriter.write(
        user: identity.user,
        issuer: billing_issuer,
        ial: billed_ial,
        request_id: "tx:#{grant.delegation_id}:#{billing_issuer}:#{billed_ial}",
        billable: true,
        access_type: SpReturnLog::ACCESS_TYPE_DELEGATED,
        retry_on_collision: true,
      )
    end

    def link_token_to(row)
      SpReturnLogBillingAdjustment.create!(
        sp_return_log: row,
        adjustment_type: :delegated_token_issued,
        token_exchange_token: issued,
      )
    end

    def waive_sign_in(delegated_row)
      sign_in_row, resolved_via = resolve_sign_in_row
      outcome = sign_in_row.nil? ? 'not_found' : WAIVER_OUTCOMES.fetch(resolved_via)
      already_waived = sign_in_row.present? && sign_in_row.excluded_from_billing?

      if sign_in_row.present?
        SpReturnLogBillingAdjustment.create!(
          sp_return_log: sign_in_row,
          adjustment_type: :exclude_from_billing,
          delegated_return_log: delegated_row,
          token_exchange_token: issued,
          resolved_via:,
        )
      end

      analytics.delegated_billing_waiver(
        outcome:,
        already_waived:,
        service_provider_issuer: service_provider.issuer,
        billing_issuer:,
      )
    end

    WAIVER_OUTCOMES = { cache: 'cache_hit', database_fallback: 'db_fallback' }.freeze
    private_constant :WAIVER_OUTCOMES

    # @return [Array(SpReturnLog, Symbol), Array(nil, nil)] the sign-in row and how it was found
    def resolve_sign_in_row
      cached_id = SignInWaiverLink.read(access_token: subject_token)
      if cached_id
        row = SpReturnLog.find_by(id: cached_id, user_id: identity.user_id)
        return [row, :cache] if row
      end

      row = sign_in_row_from_database
      row ? [row, :database_fallback] : [nil, nil]
    end

    def analytics
      @analytics ||= Analytics.new(
        user: identity.user, request: nil, session: {}, sp: service_provider.issuer,
      )
    end
  end
end
