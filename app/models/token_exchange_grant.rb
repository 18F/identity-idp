# frozen_string_literal: true

# A person's approval for one service provider to act for them at one agency application.
#
# One live row per (user, service provider, application). The row is written in two places that
# read and write the same state: the consent screen, when a service provider's sign-in request
# names the application, and the account page, where the person can approve an application in
# advance. A new decision for the same key supersedes the earlier live row; nothing is deleted,
# so the record of what the person approved, and when they changed it, is kept.
#
# Validity (see #valid_now?) is decided from the row alone plus the current content versions:
# not revoked, remembered and still within the remember period (or given in the authorization
# that is now asking), and the person saw content at or above every owner's current material
# version. A revoked service provider connection ends the approval through #revoke!.
class TokenExchangeGrant < ApplicationRecord
  SOURCES = %w[consent_screen account_page].freeze
  # Remembered approvals last at most as long as the person's consent to the service provider.
  MAX_REMEMBER = ServiceProviderIdentity::CONSENT_EXPIRATION
  DELEGATION_ID_PREFIX = 'dlg_'

  belongs_to :user
  belongs_to :application, class_name: 'ServiceProvider',
                           foreign_key: :application_service_provider_id, inverse_of: false
  # The approved service provider, joined on its issuer the way ServiceProviderIdentity joins
  # its record. Optional so a row whose service provider was removed from the registry still
  # loads; #valid_now? then refuses it.
  belongs_to :service_provider_record, class_name: 'ServiceProvider',
                                       foreign_key: :service_provider_issuer,
                                       primary_key: :issuer, optional: true, inverse_of: false
  # Issuance records of the delegated tokens issued under this approval.
  has_many :token_exchange_tokens, foreign_key: :grant_id, inverse_of: :grant, dependent: nil

  validates :service_provider_issuer, :consented_at, presence: true
  validates :source, inclusion: { in: SOURCES }
  validates :delegation_id, presence: true, uniqueness: true

  before_validation :assign_delegation_id, on: :create

  # Not revoked. The live row is the one both screens read.
  scope :live, -> { where(revoked_at: nil) }
  # Live and remembered beyond this moment.
  scope :remembered, -> { live.where('remember_until > ?', Time.zone.now) }
  scope :for_service_provider, ->(issuer) { where(service_provider_issuer: issuer) }

  def self.generate_delegation_id
    DELEGATION_ID_PREFIX + SecureRandom.urlsafe_base64(16)
  end

  # The live approval for one (user, service provider, application), if any.
  def self.live_for(user:, service_provider_issuer:, application:)
    live.find_by(user:, service_provider_issuer:, application:)
  end

  # The live approvals for several applications in one query, keyed by application id. Each
  # grant's application association is set to the record passed in, so freshness checks read the
  # application (and whatever the caller loaded on it) without another query per grant.
  # @param applications [Array<ServiceProvider>]
  # @return [Hash{Integer => TokenExchangeGrant}]
  def self.live_by_application(user:, service_provider_issuer:, applications:)
    by_id = applications.index_by(&:id)
    return {} if by_id.empty?

    grants = live.where(
      user:, service_provider_issuer:,
      application_service_provider_id: by_id.keys
    )
    grants.each { |grant| grant.application = by_id[grant.application_service_provider_id] }
    grants.index_by(&:application_service_provider_id)
  end

  # Splits the applications a service provider requested into the ones the person need not be
  # asked about again and the ones that need a decision. An application is kept when its live
  # approval is remembered, unexpired and given under content that has not materially changed;
  # every other application (no live approval, a single-authorization one, an expired or stale
  # one) needs approval. Freshness reads each application's agency, so the agencies are loaded
  # in one query here and stay loaded for whatever the caller does with the applications next.
  #
  # @param applications [Array<ServiceProvider>] in request order, which both lists keep
  # @return [Hash{Symbol => Array}] +kept+ as grants, +needing_approval+ as applications
  def self.partition_current(user:, service_provider_issuer:, applications:)
    ActiveRecord::Associations::Preloader.new(records: applications, associations: :agency).call
    grants = live_by_application(user:, service_provider_issuer:, applications:)

    kept = []
    needing_approval = []
    applications.each do |application|
      grant = grants[application.id]
      if grant&.remembered_and_current?
        kept << grant
      else
        needing_approval << application
      end
    end
    { kept:, needing_approval: }
  end

  # Whether a live, currently valid approval lets +service_provider_issuer+ act for +user+ at
  # +application+. Used at exchange time.
  def self.authorizes?(user:, service_provider_issuer:, application:, current_authorization: nil)
    return false if application.blank?

    grant = live_for(user:, service_provider_issuer:, application:)
    grant.present? && grant.valid_now?(current_authorization:)
  end

  # Records an approval, superseding any earlier live row for the same key so exactly one live
  # row remains. Runs in one transaction under a lock on the user so two concurrent approvals
  # (for example the account page and a sign-in in another tab) cannot both leave a live row.
  #
  # @param service_provider [ServiceProvider] the service provider being approved
  # @param application [ServiceProvider] the application it may act at
  # @param source [String] 'consent_screen' or 'account_page'
  # @param remember [Boolean] true to remember for the maximum period; false for this
  #   authorization only (then +rails_session_id+ identifies that authorization)
  # @param rails_session_id [String, nil] browser session of a single-authorization approval
  # @param proofed_in_session [Boolean] identity verification happened in the sign-in leading here
  # @param now [Time]
  # @return [TokenExchangeGrant] the new live row
  def self.approve!(
    user:, service_provider:, application:, source:, remember:,
    rails_session_id: nil, proofed_in_session: false, now: Time.zone.now
  )
    transaction do
      user.lock!
      live.where(user:, service_provider_issuer: service_provider.issuer, application:)
        .find_each { |earlier| earlier.revoke!(reason: 'superseded_by_new_consent', now:) }

      create!(
        user:,
        service_provider_issuer: service_provider.issuer,
        application:,
        source:,
        consented_at: now,
        remember_until: (now + MAX_REMEMBER if remember),
        rails_session_id: (rails_session_id unless remember),
        # The content versions the person saw, compared later against each owner's material
        # version to decide whether the approval is still current.
        agency_content_version: application.agency&.consent_content_version || 1,
        application_content_version: application.consent_content_version,
        sp_content_version: service_provider.sp_content_version,
        proofed_in_session:,
      )
    end
  end

  # Revokes the live approval for one key, if there is one.
  def self.revoke_for!(user:, service_provider_issuer:, application:, reason:, now: Time.zone.now)
    live.where(user:, service_provider_issuer:, application:)
      .find_each { |grant| grant.revoke!(reason:, now:) }
  end

  # Revokes every live approval the user gave to one service provider, for example when the
  # person disconnects that service provider from their account.
  def self.revoke_all_for!(user:, service_provider_issuer:, reason:, now: Time.zone.now)
    live.where(user:, service_provider_issuer:).find_each { |grant| grant.revoke!(reason:, now:) }
  end

  def revoked?
    revoked_at.present?
  end

  def remembered?
    remember_until.present?
  end

  # A live approval that is remembered, still within its period, and given under content that has
  # not materially changed since. The consent screen is skipped for such an application and a later
  # screen leaves the approval untouched.
  def remembered_and_current?
    !revoked? && remembered? && remember_until.future? && current_content?
  end

  # Time left on a remembered approval, never negative; nil for a single-authorization approval.
  def time_remaining
    return nil unless remembered?

    [remember_until - Time.zone.now, 0].max
  end

  # Whether this approval currently authorizes delegation.
  #
  # The checks, in order:
  # 1. The row is live (not revoked).
  # 2. The application, its agency and the service provider are still active and registered, so
  #    disabling any of them stops delegation at the next check.
  # 3. The person saw content at or above every owner's material version (#current_content?).
  # 4. Either the approval is remembered and the period has not passed, or it was given in the
  #    authorization that is asking now. For a single-authorization approval the caller passes
  #    +current_authorization+ when it knows the answer from context; otherwise the browser
  #    session recorded on the row must match the service provider identity's session, read
  #    from +identity+ when the caller has it loaded and looked up otherwise.
  def valid_now?(current_authorization: nil, identity: nil)
    return false if revoked?
    return false unless application&.delegation_application?
    return false unless service_provider_record&.delegation_service_provider?
    return false unless current_content?
    return true if remembered? && remember_until.future?
    return current_authorization unless current_authorization.nil?

    current_authorization?(identity:)
  end

  # A single-authorization approval is "the current authorization" exactly while the browser
  # session it was given in is still the session the service provider identity is bound to; the
  # next sign-in to the service provider replaces that session and the approval lapses.
  #
  # @param identity [ServiceProviderIdentity, nil] the user's identity at this approval's service
  #   provider, when the caller already holds it; looked up otherwise
  def current_authorization?(identity: nil)
    return false if rails_session_id.blank?

    identity ||= user.identities.find_by(service_provider: service_provider_issuer)
    identity.present? && identity.rails_session_id == rails_session_id
  end

  # True while no content owner has made a material change since the person approved. Each
  # owner bumps its content version on every edit and sets the material version only for
  # changes it marks as material; only those invalidate approvals.
  def current_content?
    agency_content_version >= (application.agency&.consent_material_version || 1) &&
      application_content_version >= application.consent_material_version &&
      sp_content_version >= (service_provider_record&.sp_material_version || 1)
  end

  # Ends this approval; the row is kept for the record. Every delegated token still live under
  # it stops working at once: the Redis entries listed in the approval's index set are removed,
  # so introspection answers "not active" from the next call, and the issuance records are
  # marked revoked with the same reason so the history shows why they ended.
  def revoke!(reason:, now: Time.zone.now)
    update!(revoked_at: now, revocation_reason: reason)
    DelegatedTokenStore.revoke_grant(id)
    # rubocop:disable Rails/SkipsModelValidations
    token_exchange_tokens.where(revoked_at: nil)
      .update_all(revoked_at: now, revocation_reason: reason, updated_at: now)
    # rubocop:enable Rails/SkipsModelValidations
  end

  private

  def assign_delegation_id
    self.delegation_id ||= self.class.generate_delegation_id
  end
end
