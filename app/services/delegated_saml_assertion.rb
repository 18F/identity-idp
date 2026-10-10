# frozen_string_literal: true

# The SAML 2.0 assertion issued in place of an opaque access token when a service provider asks
# the token exchange for `requested_token_type=urn:ietf:params:oauth:token-type:saml2`
# (RFC 8693 §2.1). Per RFC 8693 §3 the token is the base64url-encoded assertion itself, not a
# `<samlp:Response>`, and the agency API verifies it on its own against Login.gov's published
# SAML signing certificate instead of calling introspection.
#
# This is an adapter, not a builder. It feeds `SamlIdp::AssertionBuilder`, the class every SAML
# sign-in goes through, the values a browser flow takes from the AuthnRequest and the session:
#
# * `Issuer` is the SAML metadata entityID, and the assertion is signed with the current SAML
#   endpoint key, whose certificate that metadata publishes (SAML 2.0 Core §5).
# * `Subject/NameID` (persistent format) is the person's identifier for the agency, the same
#   value introspection reports as `sub` and a direct sign-in to that agency would produce.
# * The bearer `SubjectConfirmation` names the resource server as `Recipient` and carries no
#   `InResponseTo`, since there is no request to answer (SAML 2.0 Profiles §4.1.4.2 requires the
#   attribute only when answering one).
# * `Conditions/AudienceRestriction/Audience` is the resource server identifier and nothing else:
#   one assertion is good at one API (SAML 2.0 Core §2.5.1.4).
# * `Conditions/@NotOnOrAfter` and `SubjectConfirmationData/@NotOnOrAfter` are both the issuance
#   record's expiry, so no validator accepts the assertion past the window Login.gov recorded.
# * `AuthnStatement` describes the service provider's sign-in: its authentication instant and the
#   verified-identity context the exchange requires.
#
# The attribute statement is what the agency receives at a direct sign-in, produced by
# `AttributeAsserter` for the agency application's registered bundle, plus the delegation
# attributes:
#
# * `delegation_scopes` - the approved access, the token's `scope`
# * `delegation_id`     - the identifier that ties the assertion to the approval, the fraud-signal
#                          events and the account page
# * `actor`             - the service provider acting for the person, the SAML counterpart of the
#                          `act` claim introspection returns (RFC 8693 §4.1)
# * `dpop_jkt`          - when the family is bound to a key, the RFC 7638 thumbprint of that key,
#                          so a SAML consumer can apply the same possession check as `cnf.jkt`
#
# Proofed attributes come from the person's decrypted profile, which Login.gov holds only in the
# service provider's live sign-in session (the same place userinfo and introspection read it).
# While that session is live the bundle is released as registered; once it has ended only the
# identifiers (`uuid`, `ial`, `aal`), the email attributes and the delegation attributes remain,
# and #identifiers_only? tells the caller so the token response can report `session_live: false`.
#
# The assertion is encrypted to the resource server's registered certificate when it has one
# (SAML 2.0 Core §2.3.4, `EncryptedAssertion`) and returned signed in the clear otherwise.
class DelegatedSamlAssertion
  # The attributes that remain when the decrypted profile is not available: they come from the
  # account, not from the profile.
  IDENTIFIER_ATTRIBUTES = %i[uuid ial aal email all_emails].freeze
  # Attributes that describe a browser session and have no meaning for a delegated assertion.
  SESSION_ONLY_ATTRIBUTES = %i[locale].freeze
  KEY_TRANSPORT = 'rsa-oaep-mgf1p'
  # The block cipher used when the agency application's own setting would turn encryption off;
  # a registered certificate means the agency expects an encrypted assertion.
  DEFAULT_BLOCK_ENCRYPTION = 'aes256-cbc'
  # An encoded assertion presented back to Login.gov is a few kilobytes; anything far larger is
  # not one and is not parsed.
  MAX_ENCODED_ASSERTION_BYTES = 64 * 1024

  attr_reader :assertion_id

  # A fresh `Assertion/@ID`: an xs:ID, so it starts with a letter or underscore (XML Schema Part 2
  # §3.3.8). It is chosen before the issuance record is written because its digest is the key of
  # the live entry (DelegatedTokenStore), the way the token string is for an access token.
  def self.new_assertion_id
    "_#{SecureRandom.uuid}"
  end

  # The string whose digest keys the live entry for whatever a caller presents as `token`: the
  # `ID` of an encoded plaintext assertion, otherwise the value itself (an access token, or an
  # assertion ID the agency read from the assertion). An encrypted assertion hides its ID, so the
  # service provider that holds one revokes or introspects by the ID or by its refresh token.
  # @param presented [String, nil]
  # @return [String, nil]
  def self.reference_for(presented)
    return nil if presented.blank?

    assertion_id_in(presented) || presented
  end

  # The `ID` of a base64url- or base64-encoded `<saml:Assertion>`, or nil for anything else.
  def self.assertion_id_in(presented)
    return nil unless presented.is_a?(String) &&
                      presented.bytesize <= MAX_ENCODED_ASSERTION_BYTES &&
                      presented.match?(%r{\A[A-Za-z0-9_+/-]+={0,2}\z})

    xml = Base64.urlsafe_decode64(presented)
    return nil unless xml.start_with?('<')

    root = Nokogiri::XML(xml) { |config| config.strict.nonet }.root
    return nil unless root&.name == 'Assertion' &&
                      root.namespace&.href == Saml::XML::Namespaces::ASSERTION

    root['ID'].presence
  rescue ArgumentError, Nokogiri::XML::SyntaxError
    nil
  end

  # @param issued [TokenExchangeToken] the issuance record this assertion embodies; its scope,
  #   delegation id, assurance levels, key binding and session are what is asserted
  # @param assertion_id [String] from `.new_assertion_id`
  # @param issued_at [Time] the assertion's `IssueInstant`; the record's own issuance instant
  #   unless a refresh passes the new token's
  # @param lifetime_seconds [Integer] both validity windows, counted from +issued_at+; the
  #   record's own lifetime unless a refresh passes the new token's
  def initialize(issued:, assertion_id:, issued_at: issued.issued_at,
                 lifetime_seconds: issued.lifetime_seconds)
    @issued = issued
    @assertion_id = assertion_id
    @issued_at = issued_at
    @lifetime_seconds = lifetime_seconds
    @user = issued.user
    @resource_server = issued.resource_server
    @application = @resource_server.service_provider
    @endpoint = SamlEndpoint.new(SamlEndpoint.suffixes.last)
  end

  # @return [String] the signed (and, when the resource server has a certificate, encrypted)
  #   assertion, base64url-encoded without padding (RFC 8693 §3)
  def encoded
    @encoded ||= begin
      @user.asserted_attributes = asserted_attributes
      xml = encryption_opts ? builder.encrypt(sign: true) : builder.signed
      Base64.urlsafe_encode64(xml, padding: false)
    end
  end

  # Whether the assertion carries identifiers and email only, because the service provider's
  # sign-in has ended or holds no decrypted profile.
  def identifiers_only?
    decrypted_pii.nil?
  end

  private

  attr_reader :issued, :user, :resource_server, :application, :endpoint, :issued_at,
              :lifetime_seconds

  # The same positional arguments `SamlIdp::SamlResponse#assertion_builder` passes for a sign-in,
  # with the exchange supplying what an AuthnRequest normally would. Both validity windows are
  # the token's lifetime, counted from its issuance instant.
  def builder
    @builder ||= SamlIdp::AssertionBuilder.new(
      assertion_id.delete_prefix('_'), # the builder prefixes the underscore
      SamlIdp.config.base_saml_location, # Issuer, also the metadata entityID
      user,
      resource_server.identifier, # Conditions/AudienceRestriction/Audience
      nil, # no AuthnRequest, so no InResponseTo
      resource_server.identifier, # SubjectConfirmationData/@Recipient
      SamlIdp.config.algorithm,
      Saml::Idp::Constants::IAL_VERIFIED_ACR,
      Saml::Idp::Constants::NAME_ID_FORMAT_PERSISTENT,
      endpoint.x509_certificate,
      endpoint.secret_key,
      authn_instant,
      lifetime_seconds,
      encryption_opts,
      subject_confirmation_expiry: lifetime_seconds,
      issue_instant: issued_at,
    )
  end

  # Encryption to the resource server's own certificate, with the agency application's block
  # cipher; nil, for an assertion returned signed in the clear, when no certificate is registered.
  def encryption_opts
    return @encryption_opts if defined?(@encryption_opts)

    cert = resource_server.ssl_certs.first
    @encryption_opts = cert && {
      cert:,
      block_encryption: application.encrypt_responses? ? application.block_encryption
                                                       : DEFAULT_BLOCK_ENCRYPTION,
      key_transport: KEY_TRANSPORT,
    }
  end

  # When the person last authenticated to the service provider, the sign-in this delegation rests
  # on; the issuance instant if the connection carries no such instant.
  def authn_instant
    identity&.last_authenticated_at || issued_at
  end

  # The agency application's bundle as at a direct sign-in, reduced to the identifiers when the
  # profile cannot be read, then the delegation attributes.
  def asserted_attributes
    attrs = AttributeAsserter.new(
      user:,
      service_provider: application,
      name_id_format: Saml::Idp::Constants::NAME_ID_FORMAT_PERSISTENT,
      authn_request: nil,
      ial: issued.ial,
      aal: issued.aal,
      decrypted_pii:,
      user_session: {},
    ).build
    attrs = attrs.select { |name, _| IDENTIFIER_ATTRIBUTES.include?(name) } if identifiers_only?
    attrs = attrs.except(*SESSION_ONLY_ATTRIBUTES)
    # The person has no connection to the agency application (the exchange never creates one),
    # so the two getters that would read it are replaced with what introspection reports.
    attrs[:uuid] = attrs[:uuid].merge(getter: ->(_principal) { claims.agency_sub })
    attrs[:email] = attrs[:email].merge(getter: ->(_principal) { email }) if attrs[:email]
    attrs.merge(delegation_attributes)
  end

  def delegation_attributes
    attrs = {
      delegation_scopes: { getter: ->(_principal) { issued.scope } },
      delegation_id: { getter: ->(_principal) { issued.delegation_id } },
      actor: { getter: ->(_principal) { issued.service_provider.issuer } },
    }
    attrs[:dpop_jkt] = { getter: ->(_principal) { issued.dpop_jkt } } if issued.key_bound?
    attrs
  end

  # The same view of the person introspection takes: the agency identifier and whether the
  # service provider's sign-in is still live.
  def claims
    @claims ||= DelegatedTokenClaims.new(
      user:,
      identity:,
      application:,
      ial: issued.ial,
      aal: issued.aal,
      sp_rails_session_id: issued.sp_rails_session_id,
    )
  end

  # The person's connection to the acting service provider, which holds the email they chose to
  # share and the sign-in's authentication instant.
  def identity
    return @identity if defined?(@identity)

    @identity = ServiceProviderIdentity.not_deleted
      .find_by(user:, service_provider: issued.service_provider.issuer)
  end

  # The address the person chose to share with the service provider; there is no separate choice
  # recorded for the agency in a delegated flow.
  def email
    (identity&.email_address_for_sharing || user.last_sign_in_email_address).email
  end

  # @return [Pii::Attributes, nil] the decrypted profile from the service provider's live sign-in
  #   session; nil once that session has ended or when it holds none
  def decrypted_pii
    return @decrypted_pii if defined?(@decrypted_pii)

    profile_id = user.active_profile&.id
    @decrypted_pii =
      if claims.session_live? && profile_id
        OutOfBandSessionAccessor.new(issued.sp_rails_session_id).load_pii(profile_id)
      end
  end
end
