# frozen_string_literal: true

# Records the person's approval of the applications a service provider requested, from the
# consent screen.
#
# The screen shows every requested application locked: the person either approves them all by
# continuing or declines them all by cancelling, so this service never receives a partial choice.
# What it does receive is the remember choice, and it applies that choice only to applications
# that lack a current remembered approval:
#
# 1. An application with a live approval that is remembered, unexpired and current (no material
#    content change since) is left untouched. A later screen never shortens an approval the person
#    already gave, from the account page or an earlier screen.
# 2. Every other requested application gets a new approval row: remembered for the maximum period
#    when the person asked, otherwise valid for this authorization only (identified by the browser
#    session). An earlier live row for the same application (stale or single-authorization) is
#    superseded by TokenExchangeGrant.approve!.
class TokenExchangeConsent
  Result = Struct.new(:approved, :kept, keyword_init: true) do
    def all
      approved + kept
    end
  end

  # @param user [User]
  # @param service_provider [ServiceProvider] the service provider the person is signing in to
  # @param applications [Array<ServiceProvider>] the applications named in the request
  # @param remember [Boolean] the remember choice for applications without a current approval
  # @param rails_session_id [String] the browser session of this authorization
  # @param proofed_in_session [Boolean] identity verification happened in this sign-in
  def initialize(user:, service_provider:, applications:, remember:, rails_session_id:,
                 proofed_in_session: false)
    @user = user
    @service_provider = service_provider
    @applications = applications
    @remember = remember
    @rails_session_id = rails_session_id
    @proofed_in_session = proofed_in_session
  end

  # @return [Result] the approvals written now (`approved`) and the remembered ones kept (`kept`)
  def call
    approved = []
    kept = []
    now = Time.zone.now

    # Every application's agency is read below, either to judge an existing approval's freshness
    # or to record the agency's content version on the new row, so the agencies are loaded in one
    # query rather than one per application.
    ActiveRecord::Associations::Preloader.new(records: applications, associations: :agency).call
    existing_by_application_id = TokenExchangeGrant.live_by_application(
      user:, service_provider_issuer: service_provider.issuer, applications:,
    )

    TokenExchangeGrant.transaction do
      applications.each do |application|
        existing = existing_by_application_id[application.id]
        if existing&.remembered_and_current?
          kept << existing
          next
        end

        approved << TokenExchangeGrant.approve!(
          user:, service_provider:, application:,
          source: 'consent_screen',
          remember:,
          rails_session_id:,
          proofed_in_session:,
          now:
        )
      end
    end

    Result.new(approved:, kept:)
  end

  private

  attr_reader :user, :service_provider, :applications, :remember, :rails_session_id,
              :proofed_in_session
end
