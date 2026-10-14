# frozen_string_literal: true

# What an introspection response says about the person a delegated token stands for.
#
# The agency API the token was issued for reads the person exactly as it would after a direct
# sign-in: the same identifier (`sub`), the same claim names and formats userinfo produces, and
# the assurance of the sign-in in the vocabulary userinfo uses. Which identity attributes are
# released is decided by the agency application's registered attribute bundle alone, never by the
# scopes the service provider requested for its own sign-in: the person approved the agency
# receiving its bundle and the service provider acting, not the service provider choosing what
# the agency learns. Bundle names are the attribute names agency registrations already use
# (`first_name`, `address1`, `dob`, ...); each maps to the OpenID Connect scope that releases the
# matching claim and the userinfo scoper then keeps only those claims.
#
# Proofed attributes come from the person's decrypted profile, which Login.gov holds only in the
# service provider's live sign-in session (the same place userinfo reads it). While that session
# is live the bundle is released as registered; once it ends, only the identifiers and the email
# address remain, and #session_live? tells the caller which case it is in.
#
# The same formatting serves the attributes an application chooses to share with the service
# provider itself (#shared_with_service_provider): that list is bounded by the agency's bundle,
# since an application cannot pass on what it is not entitled to receive.
class DelegatedTokenClaims
  include Rails.application.routes.url_helpers

  # Attribute-bundle name => the OpenID Connect scope that releases the equivalent claim.
  BUNDLE_SCOPES = {
    'email' => 'email',
    'all_emails' => 'all_emails',
    'first_name' => 'profile:name',
    'last_name' => 'profile:name',
    'dob' => 'profile:birthdate',
    'ssn' => 'social_security_number',
    'phone' => 'phone',
    'address1' => 'address',
    'address2' => 'address',
    'city' => 'address',
    'state' => 'address',
    'zipcode' => 'address',
    'verified_at' => 'profile:verified_at',
    'x509_subject' => 'x509:subject',
    'x509_issuer' => 'x509:issuer',
    'x509_presented' => 'x509:presented',
  }.freeze

  # `profile:name` releases both names together, while a bundle names them one at a time, so
  # each name claim is also checked against the bundle on its own.
  NAME_CLAIM_BUNDLE_NAMES = { given_name: 'first_name', family_name: 'last_name' }.freeze

  # The attributes that remain available once the service provider's sign-in has ended: they
  # come from the account, not from the decrypted profile held in the session.
  SESSION_INDEPENDENT_ATTRIBUTES = %w[email all_emails].freeze

  # @param user [User] the person
  # @param identity [ServiceProviderIdentity, nil] the person's connection to the acting service
  #   provider, which holds the email they chose to share and the sign-in's authentication context
  # @param application [ServiceProvider] the agency application whose API the token is for; its
  #   `attribute_bundle` bounds what is released
  # @param ial [Integer, nil] identity assurance forwarded from the service provider's sign-in
  # @param aal [Integer, nil] authentication assurance forwarded from that sign-in
  # @param sp_rails_session_id [String, nil] the browser session of that sign-in
  def initialize(user:, identity:, application:, ial:, aal:, sp_rails_session_id:)
    @user = user
    @identity = identity
    @application = application
    @ial = ial
    @aal = aal
    @sp_rails_session_id = sp_rails_session_id
  end

  # The person's pairwise identifier for the application's agency, the one a direct sign-in to
  # any of that agency's services produces. Created here if the person has never used the
  # agency; no connection to the application is recorded.
  def agency_sub
    AgencyIdentityLinker.for(user:, service_provider: application, skip_create: false).uuid
  end

  # Whether the service provider's sign-in, and with it the decrypted profile, is still live.
  def session_live?
    return @session_live if defined?(@session_live)

    @session_live = sp_rails_session_id.present? && session_accessor.ttl.positive?
  end

  # The identity assurance of the sign-in, as userinfo reports `ial`: verified only when the
  # token was issued for a verified sign-in and the person still holds an active profile.
  def acr
    verified? ? Saml::Idp::Constants::IAL_VERIFIED_ACR : Saml::Idp::Constants::IAL_AUTH_ONLY_ACR
  end

  # The authentication assurance of the sign-in, as userinfo reports `aal`: the level recorded
  # on the token when the sign-in stored one, otherwise what the sign-in asserted.
  def aal_acr
    Saml::Idp::Constants::AUTHN_CONTEXT_AAL_TO_CLASSREF[aal] ||
      identity&.requested_aal_value.presence ||
      Saml::Idp::Constants::DEFAULT_AAL_AUTHN_CONTEXT_CLASSREF
  end

  # The claims for the agency API: its whole bundle while the sign-in is live, email alone (with
  # `all_emails` when bundled) once it has ended. Email is released in both cases.
  def agency_claims
    names = session_live? ? bundle : (bundle & SESSION_INDEPENDENT_ATTRIBUTES)
    claims_for(names | ['email'])
  end

  # The claims the application has chosen to share with the service provider, limited to what the
  # application's own bundle contains. Empty unless the agency decided otherwise.
  def shared_with_service_provider
    claims_for(Array(application.delegation_sp_shareable_attributes).map(&:to_s) & bundle)
  end

  def url_options
    {}
  end

  private

  attr_reader :user, :identity, :application, :ial, :aal, :sp_rails_session_id

  # Userinfo-shaped claims for the named attributes. Every claim userinfo could produce is built
  # and the scoper keeps those the names release, so the output matches userinfo claim for claim;
  # a claim whose source is unavailable (no live session, no PIV/CAC) is left out rather than
  # released empty.
  def claims_for(names)
    names = names.map(&:to_s) & BUNDLE_SCOPES.keys
    return {} if names.empty?

    scoper = OpenidConnectAttributeScoper.new(
      (['openid'] + names.map { |name| BUNDLE_SCOPES[name] }).uniq.join(' '),
    )

    info = { email: email, email_verified: true }
    info[:all_emails] = user.confirmed_email_addresses.map(&:email) if scoper.all_emails_requested?
    if scoper.ial2_scopes_requested? && verified? && pii.present?
      info.merge!(OpenidConnectClaimsFormatter.new(pii:).identity_proofing_claims)
    end
    if scoper.x509_scopes_requested? && session_live? && identity&.piv_cac_enabled?
      info.merge!(OpenidConnectClaimsFormatter.new(x509: session_accessor.load_x509).x509_claims)
    end
    info[:verified_at] = verified_at if scoper.verified_at_requested? && verified?

    scoper.filter(info).reject do |claim, _value|
      NAME_CLAIM_BUNDLE_NAMES.key?(claim) && !names.include?(NAME_CLAIM_BUNDLE_NAMES[claim])
    end
  end

  def bundle
    @bundle ||= Array(application.attribute_bundle).map(&:to_s)
  end

  # The address the person chose to share with the service provider, as userinfo reports it to
  # that service provider; a person who never used the agency directly has no separate choice
  # recorded there.
  def email
    (identity&.email_address_for_sharing || user.last_sign_in_email_address).email
  end

  def verified?
    active_profile.present? && [Idp::Constants::IAL2, Idp::Constants::IAL_MAX].include?(ial)
  end

  def verified_at
    return nil if application.ial.to_i < Idp::Constants::IAL2

    active_profile&.verified_at&.to_i
  end

  def active_profile
    user.active_profile
  end

  # @return [Pii::Attributes, nil] nil once the service provider's sign-in has ended
  def pii
    return @pii if defined?(@pii)

    @pii = (session_accessor.load_pii(active_profile.id) if session_live? && active_profile)
  end

  def session_accessor
    @session_accessor ||= OutOfBandSessionAccessor.new(sp_rails_session_id)
  end
end
