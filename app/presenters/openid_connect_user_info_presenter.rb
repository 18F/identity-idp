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
      email: identity.email_address_for_sharing.email,
      email_verified: true,
    }

    info[:all_emails] = all_emails_from_sp_identity(identity) if scoper.all_emails_requested?
    info[:locale] = web_locale if scoper.locale_requested?
    info.merge!(ial2_attributes) if identity_proofing_requested_for_verified_user?
    # Emitted whenever sharing is authorized, even if empty: an empty hash tells
    # the RP "authorized, but the artifacts have not landed yet, retry", whereas
    # omitting the claim means sharing is not authorized for this identity.
    if scoper.document_images_requested? && document_images_shareable?
      info[:document_images] = document_images
      info[:document_metadata] = document_metadata
    end
    info.merge!(x509_attributes) if scoper.x509_scopes_requested?
    info[:verified_at] = verified_at if scoper.verified_at_requested?
    info[:ial] = authn_context_resolver.asserted_ial_acr
    info[:aal] = requested_aal_value
    info[:auth_time] = auth_time

    scoper.filter(info)
  end

  def url_options
    {}
  end

  private

  def analytics
    Analytics.new(user: identity.user, request: nil, session: {}, sp: nil)
  end

  def requested_aal_value
    if identity.requested_aal_value != authn_context_resolver.asserted_aal_acr
      analytics.asserted_aal_different_from_response_aal(
        asserted_aal_value: authn_context_resolver.asserted_aal_acr,
        client_id: identity&.service_provider_record&.issuer,
        response_aal_value: identity.requested_aal_value,
      )
    end

    identity.requested_aal_value
  end

  def uuid_from_sp_identity(identity)
    AgencyIdentityLinker.new(identity).link_identity.uuid
  end

  def all_emails_from_sp_identity(identity)
    identity.user.confirmed_email_addresses.map(&:email)
  end

  def web_locale
    out_of_band_session_accessor.load_web_locale
  end

  def ial2_attributes
    {
      given_name: stringify_attr(ial2_data.first_name),
      family_name: stringify_attr(ial2_data.last_name),
      birthdate: dob,
      social_security_number: stringify_attr(ial2_data.ssn),
      address: address,
      phone: phone,
      phone_verified: phone.present? || nil,
    }
  end

  def x509_attributes
    {
      x509_subject: stringify_attr(x509_data.subject),
      x509_issuer: stringify_attr(x509_data.issuer),
      x509_presented: !!x509_data.presented.raw,
    }
  end

  # The images travel inside the user-information claims, so a service provider receives
  # them only within the response sealed to its registered certificate (RFC 7516). There is
  # no separate download: a URL fetched under the access token would carry the biometric
  # across Login.gov's edge under TLS alone. Each image is an object with its media type and
  # the bytes in base64url (RFC 4648 section 5, without padding), the encoding JOSE uses for
  # binary content. An artifact whose stored object is gone or can no longer be decrypted
  # is left out, so the claim names only what the service provider actually receives; an
  # empty object means authorized with nothing retrieved yet. mDL profiles have no artifacts.
  def document_images
    return @document_images if defined?(@document_images)

    @document_images =
      if document_images_shareable?
        active_profile.document_artifacts.retained.order(:image_type)
          .each_with_object({}) do |artifact, images|
          bytes = read_image(artifact)
          next if bytes.blank?

          images[artifact.image_type.to_sym] = {
            content_type: artifact.content_type,
            data: Base64.urlsafe_encode64(bytes, padding: false),
          }
        end
      else
        {}
      end
  end

  # Unwrapping the stored key and fetching the object from Redis can each fail apart from
  # the object simply being absent; every case means this image is not released.
  def read_image(artifact)
    doc_reader.read(name: artifact.storage_name, encryption_key: artifact.encryption_key)
  rescue Encryption::EncryptionError, Redis::BaseError
    nil
  end

  def doc_reader
    @doc_reader ||= EncryptedDocStorage::DocReader.new
  end

  # The images and the document identifiers are released only to a service provider on the
  # document-images list whose user-information response is also encrypted to its
  # registered certificate: the biometric must never leave Login.gov readable by the edge,
  # the logs or an intermediary, and TLS alone does not give that. A service provider on
  # the images list alone receives neither claim.
  def document_images_shareable?
    active_profile.present? &&
      resolved_authn_context_result.identity_proofing? &&
      identity.service_provider_record&.document_images_sharing_allowed? &&
      identity.service_provider_record.userinfo_encrypted_response? &&
      identity.biometric_sharing_consented?(active_profile)
  end

  # Document identifiers (number, issue/expiration dates) released inline
  # alongside the images, under the same sharing gate. Empty until the retrieval
  # job has persisted them (same async window as the images). mDL has none.
  def document_metadata
    return {} unless document_images_shareable?

    metadata = active_profile.document_metadata
    metadata&.retained? ? metadata.document_data : {}
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
    authn_context_resolver.result
  end

  def authn_context_resolver
    @authn_context_resolver ||= AuthnContextResolver.new(
      user: identity.user,
      service_provider: identity&.service_provider_record,
      acr_values: identity.acr_values,
    )
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

  def active_profile
    identity.user&.active_profile
  end

  def verified_at
    return if identity&.service_provider_record&.ial.to_i < 2

    active_profile&.verified_at&.to_i
  end

  def auth_time
    (out_of_band_session_accessor&.authentication_event_at || Time.zone.now).to_i
  end

  def out_of_band_session_accessor
    @out_of_band_session_accessor ||= OutOfBandSessionAccessor.new(identity.rails_session_id)
  end
end
