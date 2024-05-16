# frozen_string_literal: true

class OpenidConnectUserInfoPresenter
  include Rails.application.routes.url_helpers

  attr_reader :identity

  def initialize(identity, session_accessor: nil)
    @identity = identity
    @out_of_band_session_accessor = session_accessor
  end

  def user_info
    scoper = OpenidConnectAttributeScoper.new(identity.scope)
    info = {
      sub: uuid_from_sp_identity(identity),
      iss: root_url,
      email: email_from_sp_identity,
      email_verified: true,
    }

    info[:all_emails] = all_emails_from_sp_identity(identity) if scoper.all_emails_requested?
    info.merge!(ial2_attributes) if identity_proofing_requested_for_verified_user?
    info.merge!(x509_attributes) if scoper.x509_scopes_requested?
    info[:verified_at] = verified_at if scoper.verified_at_requested?
    if identity.vtr.nil?
      info[:ial] = if identity_proofing_requested_for_verified_user?
                     Saml::Idp::Constants::IAL2_AUTHN_CONTEXT_CLASSREF
                   else
                     Saml::Idp::Constants::IAL1_AUTHN_CONTEXT_CLASSREF
                   end
      info[:aal] = identity.requested_aal_value
    else
      info[:vot] = vot_values
      info[:vtm] = IdentityConfig.store.vtm_url
    end

    scoper.filter(info)
  end

  def url_options
    {}
  end

  private

  def vot_values
    vot = JSON.parse(identity.vtr).first
    parsed_vot = Vot::Parser.new(vector_of_trust: vot).parse
    parsed_vot.expanded_component_values
  end

  def uuid_from_sp_identity(identity)
    AgencyIdentityLinker.new(identity).link_identity.uuid
  end

  def email_from_sp_identity
    email_context.last_sign_in_email_address.email
  end

  def all_emails_from_sp_identity(identity)
    identity.user.confirmed_email_addresses.map(&:email)
  end

  def email_context
    @email_context ||= EmailContext.new(identity.user)
  end

  def ial2_attributes
    {
      given_name: stringify_attr(ial2_data.first_name),
      family_name: stringify_attr(ial2_data.last_name),
      birthdate: dob,
      social_security_number: stringify_attr(ial2_data.ssn),
      address: address,
      phone: phone,
      phone_verified: phone.present? ? true : nil,
    }
  end

  def x509_attributes
    {
      x509_subject: stringify_attr(x509_data.subject),
      x509_issuer: stringify_attr(x509_data.issuer),
      x509_presented:,
    }
  end

  def phone
    return if ial2_data.phone.blank?

    Phonelib.parse(ial2_data.phone).e164
  end

  def dob
    return if ial2_data.dob.blank?
    DateParser.parse_legacy(ial2_data.dob).to_s
  end

  def address
    return nil if ial2_data.address1.blank?

    {
      formatted: formatted_address,
      street_address: street_address,
      locality: stringify_attr(ial2_data.city),
      region: stringify_attr(ial2_data.state),
      postal_code: postal_code,
    }
  end

  def formatted_address
    [
      street_address,
      "#{ial2_data.city}, #{ial2_data.state} #{postal_code}",
    ].compact.join("\n")
  end

  def postal_code
    stringify_attr(ial2_data.zipcode)&.strip&.slice(0, 5)
  end

  def street_address
    [ial2_data.address1, ial2_data.address2].compact.join("\n")
  end

  def stringify_attr(attribute)
    attribute.to_s.presence
  end

  def ial2_data
    @ial2_data ||= out_of_band_session_accessor.load_pii(active_profile.id) ||
                   Pii::Attributes.new_from_hash({})
  end

  def identity_proofing_requested_for_verified_user?
    return false unless active_profile.present?
    resolved_authn_context_result.identity_proofing? || resolved_authn_context_result.ialmax?
  end

  def resolved_authn_context_result
    @resolved_authn_context_result ||= AuthnContextResolver.new(
      service_provider: identity&.service_provider_record,
      vtr: identity.vtr.presence && JSON.parse(identity.vtr),
      acr_values: identity.acr_values,
    ).resolve
  end

  def ial2_session?
    identity.ial == Idp::Constants::IAL2
  end

  def ialmax_session?
    identity.ial == Idp::Constants::IAL_MAX
  end

  def x509_data
    @x509_data ||= begin
      if x509_session?
        out_of_band_session_accessor.load_x509
      else
        X509::Attributes.new_from_hash({})
      end
    end
  end

  def x509_session?
    identity.piv_cac_enabled?
  end

  def x509_presented
    if IdentityConfig.store.x509_presented_hash_attribute_requested_issuers.include?(
      identity&.service_provider,
    )
      x509_data.presented
    else
      !!x509_data.presented.raw
    end
  end

  def active_profile
    identity.user&.active_profile
  end

  def verified_at
    return if identity&.service_provider_record&.ial.to_i < 2

    active_profile&.verified_at&.to_i
  end

  def out_of_band_session_accessor
    @out_of_band_session_accessor ||= OutOfBandSessionAccessor.new(identity.rails_session_id)
  end
end
