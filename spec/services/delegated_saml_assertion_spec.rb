require 'rails_helper'

# The assertion MyBenefits Assistant (Office of Benefits Coordination) obtains for the
# Retirement Benefits Portal's API (National Retirement Administration), checked the way a SAML
# relying party checks it.
RSpec.describe DelegatedSamlAssertion do
  let(:ns) do
    { 'saml' => Saml::XML::Namespaces::ASSERTION, 'ds' => Saml::XML::Namespaces::SIGNATURE }
  end
  let(:user) { create(:user, :proofed) }
  let(:service_provider) do
    create(:service_provider, :delegation_service_provider, pkce: true, certs: [])
  end
  let(:agency) { create(:agency, name: 'National Retirement Administration') }
  let(:attribute_bundle) { %w[email first_name last_name phone] }
  let(:block_encryption) { 'aes256-cbc' }
  let(:application) do
    create(
      :service_provider, :delegation_application,
      agency:, ial: 2, attribute_bundle:, block_encryption:,
      issuer: 'urn:gov:gsa:SAML:2.0.profiles:sp:sso:benefits_agency',
      friendly_name: 'Retirement Benefits Portal',
      delegation_scope_value: 'retirement_benefits'
    )
  end
  let(:certs) { [] }
  let(:resource_server) do
    create(
      :token_exchange_resource_server, :saml,
      service_provider: application, certs:,
      identifier: 'https://benefits-api.retirement.example.gov'
    )
  end
  let(:rails_session_id) { SecureRandom.hex }
  let(:sign_in_at) { Time.zone.parse('2026-10-09 14:00:00 UTC') }
  let!(:identity) do
    IdentityLinker.new(user, service_provider).link_identity(
      acr_values: Saml::Idp::Constants::IAL_VERIFIED_ACR, ial: 2, rails_session_id:,
      scope: 'openid email token_exchange:retirement_benefits'
    ).tap { |linked| linked.update!(last_authenticated_at: sign_in_at) }
  end
  let(:grant) do
    TokenExchangeGrant.approve!(
      user:, service_provider:, application:, source: 'consent_screen', remember: true,
    )
  end
  let(:issued_at) { sign_in_at + 10.minutes }
  let(:dpop_jkt) { nil }
  let(:issued) do
    create(
      :token_exchange_token, grant:, resource_server:, service_provider:, user:,
                             token_type: 'N_A', token_format: 'saml2', dpop_jkt:,
                             sp_rails_session_id: rails_session_id, ial: 2, aal: 2,
                             issued_at:, expires_at: issued_at + 300
    )
  end
  let(:pii) do
    { first_name: 'Ada', last_name: 'Lovelace', phone: '(202) 555-0100', ssn: '900-11-2222' }
  end
  let(:assertion_id) { described_class.new_assertion_id }
  let(:assertion) { described_class.new(issued:, assertion_id:) }
  let(:xml) { Base64.urlsafe_decode64(assertion.encoded) }
  let(:doc) { Nokogiri::XML(xml) }
  let(:attributes) do
    doc.xpath('/saml:Assertion/saml:AttributeStatement/saml:Attribute', ns).to_h do |attr|
      [attr['Name'], attr.xpath('./saml:AttributeValue', ns).map(&:text)]
    end
  end
  let(:endpoint) { SamlEndpoint.new(SamlEndpoint.suffixes.last) }
  let(:idp_cert) { OpenSSL::X509::Certificate.new(endpoint.x509_certificate) }

  before do
    allow(IdentityConfig.store).to receive(:token_exchange_enabled).and_return(true)
    OutOfBandSessionAccessor.new(rails_session_id).put_pii(
      profile_id: user.active_profile.id, pii:, expiration: 300,
    )
  end

  describe '.new_assertion_id' do
    it 'is a unique xs:ID starting with an underscore' do
      id = described_class.new_assertion_id
      expect(id).to match(/\A_[0-9a-f-]{36}\z/)
      expect(described_class.new_assertion_id).not_to eq(id)
    end
  end

  describe '.reference_for' do
    it 'is the ID of an encoded plaintext assertion, whether base64url or base64' do
      expect(described_class.reference_for(assertion.encoded)).to eq(assertion_id)
      expect(described_class.reference_for(Base64.strict_encode64(xml))).to eq(assertion_id)
    end

    it 'is the value itself for an assertion ID or an opaque token' do
      expect(described_class.reference_for(assertion_id)).to eq(assertion_id)
      token = TokenExchangeToken.generate_token
      expect(described_class.reference_for(token)).to eq(token)
    end

    it 'is nil for a blank value' do
      expect(described_class.reference_for(nil)).to be_nil
      expect(described_class.reference_for('')).to be_nil
    end

    it 'does not read an ID out of other XML, broken XML or oversized input' do
      other = Base64.urlsafe_encode64('<Assertion ID="_x"/>', padding: false)
      expect(described_class.reference_for(other)).to eq(other)
      broken = Base64.urlsafe_encode64('<saml:Assertion ID="_x"', padding: false)
      expect(described_class.reference_for(broken)).to eq(broken)
      huge = 'A' * (described_class::MAX_ENCODED_ASSERTION_BYTES + 1)
      expect(described_class.reference_for(huge)).to eq(huge)
    end

    context 'when the assertion is encrypted' do
      let(:certs) { ['saml_test_sp'] }

      it 'cannot read the ID and returns the value itself' do
        expect(described_class.reference_for(assertion.encoded)).to eq(assertion.encoded)
      end
    end
  end

  describe '#encoded' do
    it 'is the base64url assertion without padding, carrying the chosen ID and built once' do
      expect(assertion.encoded).to match(/\A[A-Za-z0-9_-]+\z/)
      expect(doc.root.name).to eq('Assertion')
      expect(doc.root.namespace.href).to eq(Saml::XML::Namespaces::ASSERTION)
      expect(doc.root['Version']).to eq('2.0')
      expect(doc.root['ID']).to eq(assertion_id)
      expect(assertion.encoded).to equal(assertion.encoded)
    end

    it 'is issued by the metadata entityID and signed with the published certificate' do
      expect(doc.at_xpath('/saml:Assertion/saml:Issuer', ns).text)
        .to eq(SamlIdp.config.base_saml_location)
      expect(XMLSecurity::SignedDocument.new(xml).validate_document_with_cert(idp_cert, false))
        .to eq(true)
      expect(doc.xpath('//ds:Signature', ns).size).to eq(1)
      expect(doc.at_xpath('//ds:X509Certificate', ns).text.gsub(/\s/, ''))
        .to eq(Base64.strict_encode64(idp_cert.to_der))
    end

    it 'confirms the subject to the resource server for the recorded lifetime, with no request' do
      expect(doc.root['IssueInstant']).to eq('2026-10-09T14:10:00Z')
      confirmation = doc.at_xpath('/saml:Assertion/saml:Subject/saml:SubjectConfirmation', ns)
      expect(confirmation['Method']).to eq('urn:oasis:names:tc:SAML:2.0:cm:bearer')
      data = confirmation.at_xpath('./saml:SubjectConfirmationData', ns)
      expect(data.attributes.keys).to match_array(%w[NotOnOrAfter Recipient])
      expect(data['Recipient']).to eq(resource_server.identifier)
      expect(data['NotOnOrAfter']).to eq('2026-10-09T14:15:00Z')

      conditions = doc.at_xpath('/saml:Assertion/saml:Conditions', ns)
      expect(conditions['NotBefore']).to eq('2026-10-09T14:09:55Z')
      expect(conditions['NotOnOrAfter']).to eq('2026-10-09T14:15:00Z')
      expect(conditions.element_children.map(&:name)).to eq(['AudienceRestriction'])
      expect(conditions.xpath('./saml:AudienceRestriction/saml:Audience', ns).map(&:text))
        .to eq([resource_server.identifier])
    end

    it 'describes the service provider sign-in in the authentication statement' do
      authn = doc.at_xpath('/saml:Assertion/saml:AuthnStatement', ns)
      expect(authn['AuthnInstant']).to eq('2026-10-09T14:00:00Z')
      expect(authn.at_xpath('./saml:AuthnContext/saml:AuthnContextClassRef', ns).text)
        .to eq(Saml::Idp::Constants::IAL_VERIFIED_ACR)
    end

    it 'names the person by the agency identifier without creating a connection' do
      expect { assertion.encoded }.not_to(change { ServiceProviderIdentity.count })
      agency_uuid = AgencyIdentity.find_by(user:, agency:).uuid
      expect(agency_uuid).not_to eq(identity.uuid)
      name_id = doc.at_xpath('/saml:Assertion/saml:Subject/saml:NameID', ns)
      expect(name_id['Format']).to eq(Saml::Idp::Constants::NAME_ID_FORMAT_PERSISTENT)
      expect(name_id.text).to eq(agency_uuid)
      expect(attributes['uuid']).to eq([agency_uuid])
    end

    it 'asserts the agency bundle as at a direct sign-in plus the delegation attributes' do
      expect(attributes.keys).to eq(
        %w[uuid email first_name last_name phone verified_at aal ial
           delegation_scopes delegation_id actor],
      )
      expect(attributes['email']).to eq([identity.email_address_for_sharing.email])
      expect(attributes['first_name']).to eq(['Ada'])
      expect(attributes['last_name']).to eq(['Lovelace'])
      expect(attributes['phone']).to eq(['+12025550100'])
      expect(attributes['verified_at']).to eq([user.active_profile.verified_at.iso8601])
      expect(attributes['ial']).to eq([Saml::Idp::Constants::IAL2_AUTHN_CONTEXT_CLASSREF])
      expect(attributes['aal']).to eq([Saml::Idp::Constants::AAL2_AUTHN_CONTEXT_CLASSREF])
      expect(attributes['delegation_scopes']).to eq(['token_exchange:retirement_benefits'])
      expect(attributes['delegation_id']).to eq([grant.delegation_id])
      expect(attributes['actor']).to eq([service_provider.issuer])
      expect(xml).not_to include('900-11-2222')
      expect(assertion.identifiers_only?).to eq(false)
    end

    context 'when the family is bound to a key' do
      let(:dpop_jkt) { Base64.urlsafe_encode64(SecureRandom.random_bytes(32), padding: false) }

      it 'carries the thumbprint as the dpop_jkt attribute' do
        expect(attributes['dpop_jkt']).to eq([dpop_jkt])
      end
    end

    context 'when the resource server has a certificate' do
      let(:certs) { ['saml_test_sp'] }

      it 'encrypts the signed assertion to it with the agency block cipher' do
        expect(doc.root.name).to eq('EncryptedAssertion')
        expect(doc.root.namespace.href).to eq(Saml::XML::Namespaces::ASSERTION)
        xenc = 'http://www.w3.org/2001/04/xmlenc#'
        expect(doc.at_xpath('.//xenc:EncryptionMethod/@Algorithm', 'xenc' => xenc).value)
          .to eq("#{xenc}aes256-cbc")

        plaintext = OneLogin::RubySaml::Utils.decrypt_data(
          REXML::Document.new(xml).root, saml_test_sp_private_key
        )
        inner_xml = plaintext.match(%r{(.*</(\w+:)?Assertion>)}m)[1]
        inner = Nokogiri::XML(inner_xml)
        expect(inner.root['ID']).to eq(assertion_id)
        expect(inner.xpath('//ds:Signature', ns).size).to eq(1)
        signed = XMLSecurity::SignedDocument.new(inner_xml)
        expect(signed.validate_document_with_cert(idp_cert, false)).to eq(true)
      end

      context 'when the agency application has encryption switched off for sign-ins' do
        let(:block_encryption) { 'none' }

        it 'still encrypts, with the default block cipher' do
          expect(doc.root.name).to eq('EncryptedAssertion')
          xenc = 'http://www.w3.org/2001/04/xmlenc#'
          expect(doc.at_xpath('.//xenc:EncryptionMethod/@Algorithm', 'xenc' => xenc).value)
            .to eq("#{xenc}aes256-cbc")
        end
      end
    end

    context 'when the service provider sign-in has ended' do
      before { OutOfBandSessionAccessor.new(rails_session_id).destroy }

      it 'asserts the identifiers, email and delegation attributes only' do
        expect(assertion.identifiers_only?).to eq(true)
        expect(attributes.keys).to eq(%w[uuid email aal ial delegation_scopes delegation_id actor])
        expect(attributes['email']).to eq([identity.email_address_for_sharing.email])
      end
    end

    context 'when the sign-in is live but holds no decrypted profile' do
      before do
        OutOfBandSessionAccessor.new(rails_session_id).destroy
        OutOfBandSessionAccessor.new(rails_session_id).put_empty_user_session(300)
      end

      it 'asserts identifiers only' do
        expect(assertion.identifiers_only?).to eq(true)
        expect(attributes).not_to have_key('first_name')
      end
    end

    context 'when the connection to the service provider is gone' do
      before { identity.destroy! }

      it 'falls back to the issuance instant and the last sign-in email' do
        authn = doc.at_xpath('/saml:Assertion/saml:AuthnStatement', ns)
        expect(authn['AuthnInstant']).to eq('2026-10-09T14:10:00Z')
        expect(attributes['email']).to eq([user.last_sign_in_email_address.email])
      end
    end
  end
end
