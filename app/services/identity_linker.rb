# frozen_string_literal: true

class IdentityLinker
  PRIVATE_KEY_JWT_PKCE_CODE_PREFIX = 'pkce_'

  attr_reader :user, :service_provider

  def initialize(user, service_provider)
    @user = user
    @service_provider = service_provider
    @ial = nil
    @aal = nil
    @acr_values = nil
    @vtr = nil
    @requested_aal_value = nil
  end

  def link_identity(
    code_challenge: nil,
    private_key_jwt_pkce: false,
    ial: nil,
    aal: nil,
    acr_values: nil,
    vtr: nil, # rubocop:disable Lint/UnusedMethodArgument
    requested_aal_value: nil,
    nonce: nil,
    rails_session_id: nil,
    scope: nil,
    verified_attributes: nil,
    last_consented_at: nil,
    clear_deleted_at: nil,
    email_address_id: nil
  )
    return unless user && service_provider.present?

    process_ial(ial)

    identity.update!(
      identity_attributes(private_key_jwt_pkce: private_key_jwt_pkce).merge(
        code_challenge: code_challenge,
        ial: ial,
        aal: aal,
        acr_values: acr_values,
        vtr: nil,
        requested_aal_value: requested_aal_value,
        nonce: nonce,
        rails_session_id: rails_session_id,
        scope: scope,
        verified_attributes: combined_verified_attributes(verified_attributes),
        email_address_id: email_address_id,
      ).tap do |hash|
        hash[:last_consented_at] = last_consented_at if last_consented_at
        hash[:deleted_at] = nil if clear_deleted_at
      end,
    )

    AgencyIdentityLinker.new(identity).link_identity
    identity
  end

  private

  def process_ial(ial)
    @ial = ial
    process_ial_authenticated_at
    process_verified_at
  end

  def process_ial_authenticated_at
    if ial2? || ialmax_with_active_profile?
      identity.last_ial2_authenticated_at = now
    else
      identity.last_ial1_authenticated_at = now
    end
  end

  def process_verified_at
    return unless (ial2? || ialmax_with_active_profile?) && identity.verified_at.nil?
    identity.verified_at = now
  end

  def ialmax_with_active_profile?
    @ial == Idp::Constants::IAL_MAX && user.active_profile
  end

  def ial2?
    @ial == Idp::Constants::IAL2
  end

  def identity
    @identity ||= user.identities.create_or_find_by(service_provider: service_provider.issuer)
  end

  def now
    @now ||= Time.zone.now
  end

  def identity_attributes(private_key_jwt_pkce: false)
    authorization_code = SecureRandom.uuid
    if private_key_jwt_pkce
      authorization_code = PRIVATE_KEY_JWT_PKCE_CODE_PREFIX + authorization_code
    end

    # The code's lifetime is fixed when it is issued (RFC 6749 section 4.1.2 recommends at most
    # ten minutes) and is read back at redemption, so no later write to the row can extend it.
    # The access token is minted when the code is redeemed; a new authorization clears the one
    # the client holds from the previous sign-in.
    {
      last_authenticated_at: Time.zone.now,
      session_uuid: authorization_code,
      code_expires_at: IdentityConfig.store.openid_connect_authorization_code_expiration_seconds
        .seconds.from_now,
      access_token: nil,
    }
  end

  def combined_verified_attributes(verified_attributes)
    [*identity.verified_attributes, *verified_attributes.to_a.map(&:to_s)].uniq.sort
  end
end
