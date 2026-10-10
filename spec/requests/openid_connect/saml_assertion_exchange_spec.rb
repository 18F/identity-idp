require 'rails_helper'

# RFC 8693 token exchange, refresh, RFC 7662 introspection and RFC 7009 revocation when the issued
# token is a SAML 2.0 assertion (requested_token_type=urn:ietf:params:oauth:token-type:saml2).
# MyBenefits Assistant (Office of Benefits Coordination) acts for the person at the Retirement
# Benefits Portal (National Retirement Administration), whose API consumes SAML, once as a
# browser-based public client and once as a confidential client. The assertion is checked the way
# a SAML relying party checks it: decrypted with the API's key, signature against the certificate
# the metadata endpoint publishes, issuer, subject confirmation, conditions and attributes.
RSpec.describe 'OpenID Connect token exchange for SAML assertions' do
  include Rails.application.routes.url_helpers

  let(:ns) do
    { 'saml' => Saml::XML::Namespaces::ASSERTION, 'ds' => Saml::XML::Namespaces::SIGNATURE }
  end
  let(:xenc) { 'http://www.w3.org/2001/04/xmlenc#' }
  let(:user) { create(:user, :proofed) }
  let(:agency) { create(:agency, name: 'National Retirement Administration') }
  let(:application) do
    create(
      :service_provider, :delegation_application,
      agency:, ial: 2, attribute_bundle: %w[email first_name last_name],
      block_encryption: 'aes256-cbc',
      issuer: 'urn:gov:gsa:SAML:2.0.profiles:sp:sso:benefits_agency',
      friendly_name: 'Retirement Benefits Portal',
      delegation_scope_value: 'retirement_benefits'
    )
  end
  let(:resource_server_certs) { ['saml_test_sp'] }
  let(:resource_server) do
    create(
      :token_exchange_resource_server, :saml,
      service_provider: application, certs: resource_server_certs,
      identifier: 'https://benefits-api.retirement.example.gov'
    )
  end
  let(:rails_session_id) { SecureRandom.hex }
  let(:sign_in_at) { Time.zone.parse('2026-10-09 14:00:00 UTC') }
  let!(:grant) do
    TokenExchangeGrant.approve!(
      user:, service_provider:, application:, source: 'consent_screen', remember: true,
    )
  end
  let(:pii) { { first_name: 'Ada', last_name: 'Lovelace', ssn: '900-11-2222' } }
  let(:endpoint) { SamlEndpoint.new(SamlEndpoint.suffixes.last) }
  let(:idp_cert) { OpenSSL::X509::Certificate.new(endpoint.x509_certificate) }
  let(:expected_scope) { 'token_exchange:retirement_benefits' }
  let(:exchange_params) do
    {
      grant_type: OpenidConnectTokenExchangeForm::GRANT_TYPE,
      subject_token: identity.access_token,
      subject_token_type: OpenidConnectTokenExchangeForm::ACCESS_TOKEN_TYPE,
      requested_token_type: OpenidConnectTokenExchangeForm::SAML2_TOKEN_TYPE,
      resource: resource_server.identifier,
    }
  end

  def json
    JSON.parse(response.body, symbolize_names: true)
  end

  before do
    allow(IdentityConfig.store).to receive(:token_exchange_enabled).and_return(true)
    OutOfBandSessionAccessor.new(rails_session_id).put_pii(
      profile_id: user.active_profile.id, pii:, expiration: 300,
    )
  end

  def link_identity(service_provider, dpop_jkt: nil)
    IdentityLinker.new(user, service_provider).link_identity(
      acr_values: Saml::Idp::Constants::IAL_VERIFIED_ACR,
      ial: 2,
      rails_session_id:,
      scope: 'openid email token_exchange:retirement_benefits',
      dpop_jkt:,
    ).tap { |linked| linked.update!(last_authenticated_at: sign_in_at) }
  end

  def exchange(overrides = {})
    body, headers = authenticate(
      exchange_params.merge(overrides),
      url: api_openid_connect_token_url,
      token: identity.access_token,
    )
    post(api_openid_connect_token_path, params: body, headers:)
    json
  end

  def refresh(refresh_token)
    body, headers = authenticate(
      { grant_type: 'refresh_token', refresh_token: },
      url: api_openid_connect_token_url,
    )
    post(api_openid_connect_token_path, params: body, headers:)
    json
  end

  def revoke(token)
    body, headers = authenticate({ token: }, url: api_openid_connect_revoke_url, token:)
    post(api_openid_connect_revoke_path, params: body, headers:)
  end

  def introspect_as_agency(token)
    post api_openid_connect_introspect_path, params: {
      token:,
      client_assertion_type: OpenidConnectTokenForm::CLIENT_ASSERTION_TYPE,
      client_assertion: build_client_assertion(
        client_id: resource_server.identifier, audience: api_openid_connect_introspect_url,
      ),
    }
    json
  end

  # Base64url-decodes the token and, for an EncryptedAssertion, decrypts it with the API's key.
  # @return [Array(Nokogiri::XML::Document, String)] the parsed assertion and its exact XML
  def decode_assertion(token)
    expect(token).to match(/\A[A-Za-z0-9_-]+\z/)
    xml = Base64.urlsafe_decode64(token)
    if Nokogiri::XML(xml).root.name == 'EncryptedAssertion'
      plaintext = OneLogin::RubySaml::Utils.decrypt_data(
        REXML::Document.new(xml).root, saml_test_sp_private_key
      )
      xml = plaintext.match(%r{(.*</(\w+:)?Assertion>)}m)[1]
    end
    [Nokogiri::XML(xml), xml]
  end

  def attribute_values(doc)
    doc.xpath('/saml:Assertion/saml:AttributeStatement/saml:Attribute', ns).to_h do |attr|
      [attr['Name'], attr.xpath('./saml:AttributeValue', ns).map(&:text)]
    end
  end

  def metadata_certificate
    get api_saml_metadata_path(path_year: SamlEndpoint.suffixes.last)
    Nokogiri::XML(response.body).at_xpath('//ds:X509Certificate', ns).text.gsub(/\s/, '')
  end

  # Everything that does not depend on how the client authenticates.
  shared_examples 'a SAML assertion exchange' do |bound:|
    describe 'exchange' do
      it 'returns an encrypted, signed assertion for the API and records it by its ID' do
        freeze_time do
          body = exchange

          expect(response).to have_http_status(:ok)
          expect(body.keys).to contain_exactly(
            :access_token, :issued_token_type, :token_type, :expires_in, :scope,
            :refresh_token, :refresh_token_expires_in
          )
          expect(body[:issued_token_type]).to eq(OpenidConnectTokenExchangeForm::SAML2_TOKEN_TYPE)
          expect(body[:token_type]).to eq('N_A')
          expect(body[:expires_in]).to eq(300)
          expect(body[:scope]).to eq(expected_scope)
          expect(body[:refresh_token_expires_in]).to eq(12.hours.to_i)

          raw_root = Nokogiri::XML(Base64.urlsafe_decode64(body[:access_token])).root
          expect(raw_root.name).to eq('EncryptedAssertion')
          expect(raw_root.namespace.href).to eq(Saml::XML::Namespaces::ASSERTION)
          expect(raw_root.at_xpath('.//xenc:EncryptionMethod/@Algorithm', 'xenc' => xenc).value)
            .to eq("#{xenc}aes256-cbc")

          doc, xml = decode_assertion(body[:access_token])
          assertion = doc.root
          expect(assertion.name).to eq('Assertion')
          expect(assertion['Version']).to eq('2.0')
          expect(assertion['ID']).to match(/\A_[0-9a-f-]{36}\z/)
          expect(assertion['IssueInstant']).to eq(Time.zone.now.utc.iso8601)

          # Issuer and signature: what a relying party checks against Login.gov's metadata.
          expect(doc.at_xpath('/saml:Assertion/saml:Issuer', ns).text)
            .to eq(SamlIdp.config.base_saml_location)
          expect(XMLSecurity::SignedDocument.new(xml).validate_document_with_cert(idp_cert, false))
            .to eq(true)
          expect(doc.xpath('//ds:Signature', ns).size).to eq(1)
          expect(doc.at_xpath('//ds:X509Certificate', ns).text.gsub(/\s/, ''))
            .to eq(metadata_certificate)

          # Subject: the persistent identifier for the agency, bearer confirmation for the API.
          name_id = doc.at_xpath('/saml:Assertion/saml:Subject/saml:NameID', ns)
          expect(name_id['Format']).to eq(Saml::Idp::Constants::NAME_ID_FORMAT_PERSISTENT)
          expect(name_id.text).to eq(AgencyIdentity.find_by(user:, agency:).uuid)
          expect(name_id.text).not_to eq(identity.uuid)
          data = doc.at_xpath('//saml:SubjectConfirmation/saml:SubjectConfirmationData', ns)
          expect(data.attributes.keys).to match_array(%w[NotOnOrAfter Recipient])
          expect(data['Recipient']).to eq(resource_server.identifier)
          expect(data['NotOnOrAfter']).to eq(5.minutes.from_now.utc.iso8601)

          # Conditions: the same five-minute window, the one audience, nothing else.
          conditions = doc.at_xpath('/saml:Assertion/saml:Conditions', ns)
          expect(conditions['NotBefore']).to eq(5.seconds.ago.utc.iso8601)
          expect(conditions['NotOnOrAfter']).to eq(5.minutes.from_now.utc.iso8601)
          expect(conditions.element_children.map(&:name)).to eq(['AudienceRestriction'])
          expect(conditions.xpath('./saml:AudienceRestriction/saml:Audience', ns).map(&:text))
            .to eq([resource_server.identifier])

          # Authentication statement: the service provider's sign-in.
          authn = doc.at_xpath('/saml:Assertion/saml:AuthnStatement', ns)
          expect(authn['AuthnInstant']).to eq(sign_in_at.utc.iso8601)
          expect(authn.at_xpath('./saml:AuthnContext/saml:AuthnContextClassRef', ns).text)
            .to eq(Saml::Idp::Constants::IAL_VERIFIED_ACR)

          # Attributes: the agency bundle plus the delegation attributes.
          attrs = attribute_values(doc)
          expected_names = %w[uuid email first_name last_name verified_at aal ial
                              delegation_scopes delegation_id actor]
          expected_names << 'dpop_jkt' if bound
          expect(attrs.keys).to eq(expected_names)
          expect(attrs['uuid']).to eq([name_id.text])
          expect(attrs['email']).to eq([identity.email_address_for_sharing.email])
          expect(attrs['first_name']).to eq(['Ada'])
          expect(attrs['last_name']).to eq(['Lovelace'])
          expect(attrs['ial']).to eq([Saml::Idp::Constants::IAL2_AUTHN_CONTEXT_CLASSREF])
          expect(attrs['aal']).to eq([Saml::Idp::Constants::AAL2_AUTHN_CONTEXT_CLASSREF])
          expect(attrs['delegation_scopes']).to eq([expected_scope])
          expect(attrs['delegation_id']).to eq([grant.delegation_id])
          expect(attrs['actor']).to eq([service_provider.issuer])
          expect(attrs['dpop_jkt']).to eq([dpop_thumbprint]) if bound
          expect(xml).not_to include('900-11-2222')

          # Record-keeping: the issuance record and the live entry keyed by the assertion ID.
          issued = TokenExchangeToken.last
          expect(issued.token_format).to eq('saml2')
          expect(issued.token_type).to eq('N_A')
          expect(issued.scope).to eq(expected_scope)
          expect(issued.grant).to eq(grant)
          expect(issued.dpop_jkt).to eq(bound ? dpop_thumbprint : nil)
          expect(issued.issued_at).to eq(Time.zone.now)
          expect(issued.expires_at).to eq(5.minutes.from_now)
          expect(issued.attributes.values.map(&:to_s)).not_to include(assertion['ID'])
          expect(DelegatedTokenStore.read(assertion['ID'])).to include(
            aud: resource_server.identifier,
            scope: expected_scope,
            delegation_id: grant.delegation_id,
            token_type: 'N_A',
            token_format: 'saml2',
            dpop_jkt: bound ? dpop_thumbprint : nil,
            expires_at: 5.minutes.from_now.to_i,
            issuance_id: issued.id,
          )
          expect(DelegatedTokenStore.read(body[:access_token])).to be_nil
          live_key = "#{DelegatedTokenStore::TOKEN_KEY_PREFIX}#{Digest::SHA256.hexdigest(assertion['ID'])}"
          expect(REDIS_POOL.with { |client| client.ttl(live_key) }).to eq(300)

          refresh_row = TokenExchangeRefreshToken.lookup(body[:refresh_token])
          expect(refresh_row.family_id).to eq(issued.refresh_family_id)
          expect(refresh_row).to be_saml
        end
      end

      it 'never creates a connection to the agency application' do
        expect { exchange }.not_to(change { ServiceProviderIdentity.count })
        expect(response).to have_http_status(:ok)
      end

      it 'logs the requested type and the N_A token type' do
        stub_request_analytics
        exchange
        expect(@analytics).to have_logged_event(
          :openid_connect_token_exchange,
          hash_including(
            success: true,
            requested_token_type: OpenidConnectTokenExchangeForm::SAML2_TOKEN_TYPE,
            token_type: 'N_A',
            resource_server_identifier: resource_server.identifier,
          ),
        )
      end

      it 'sizes both windows from the configured assertion lifetime' do
        allow(IdentityConfig.store).to receive(:token_exchange_saml_assertion_ttl_seconds)
          .and_return(120)
        freeze_time do
          body = exchange
          expect(body[:expires_in]).to eq(120)
          doc, = decode_assertion(body[:access_token])
          expect(doc.at_xpath('//saml:SubjectConfirmationData', ns)['NotOnOrAfter'])
            .to eq(2.minutes.from_now.utc.iso8601)
          expect(doc.at_xpath('/saml:Assertion/saml:Conditions', ns)['NotOnOrAfter'])
            .to eq(2.minutes.from_now.utc.iso8601)
          expect(TokenExchangeToken.last.expires_at).to eq(2.minutes.from_now)
        end
      end

      context 'when the API has no registered certificate' do
        let(:resource_server_certs) { [] }

        it 'returns the signed assertion in the clear' do
          body = exchange
          expect(response).to have_http_status(:ok)
          xml = Base64.urlsafe_decode64(body[:access_token])
          expect(Nokogiri::XML(xml).root.name).to eq('Assertion')
          expect(XMLSecurity::SignedDocument.new(xml).validate_document_with_cert(idp_cert, false))
            .to eq(true)
        end
      end

      context 'when the sign-in holds no decrypted profile' do
        before do
          OutOfBandSessionAccessor.new(rails_session_id).destroy
          OutOfBandSessionAccessor.new(rails_session_id).put_empty_user_session(300)
        end

        it 'issues identifiers and email only and reports the session as not live' do
          body = exchange
          expect(response).to have_http_status(:ok)
          expect(body[:session_live]).to eq(false)
          doc, = decode_assertion(body[:access_token])
          names = %w[uuid email aal ial delegation_scopes delegation_id actor]
          names << 'dpop_jkt' if bound
          expect(attribute_values(doc).keys).to eq(names)
        end
      end

      context 'when signing fails' do
        before do
          allow_any_instance_of(SamlIdp::AssertionBuilder).to receive(:signed)
            .and_raise(OpenSSL::PKey::RSAError)
          allow_any_instance_of(SamlIdp::AssertionBuilder).to receive(:encrypt)
            .and_raise(OpenSSL::PKey::RSAError)
        end

        it 'leaves no record and no live entry behind' do
          expect { exchange }.to raise_error(OpenSSL::PKey::RSAError)
          expect(TokenExchangeToken.count).to eq(0)
          expect(TokenExchangeRefreshToken.count).to eq(0)
          expect(grant.reload.first_exchanged_at).to be_nil
        end
      end
    end

    describe 'refresh' do
      let!(:first) { exchange }
      let(:first_doc) { decode_assertion(first[:access_token]).first }

      it 're-issues a new assertion for the same audience and access and rotates the token' do
        travel 2.minutes do
          body = refresh(first[:refresh_token])

          expect(response).to have_http_status(:ok)
          expect(body.keys).to contain_exactly(
            :access_token, :issued_token_type, :token_type, :expires_in, :scope,
            :refresh_token, :refresh_token_expires_in
          )
          expect(body[:issued_token_type]).to eq(OpenidConnectTokenExchangeForm::SAML2_TOKEN_TYPE)
          expect(body[:token_type]).to eq('N_A')
          expect(body[:expires_in]).to eq(300)
          expect(body[:scope]).to eq(expected_scope)
          expect(body[:refresh_token]).not_to eq(first[:refresh_token])

          doc, xml = decode_assertion(body[:access_token])
          expect(doc.root['ID']).not_to eq(first_doc.root['ID'])
          expect(doc.root['IssueInstant']).to eq(Time.zone.now.utc.iso8601)
          expect(XMLSecurity::SignedDocument.new(xml).validate_document_with_cert(idp_cert, false))
            .to eq(true)
          expect(doc.xpath('//saml:Audience', ns).map(&:text)).to eq([resource_server.identifier])
          expect(doc.at_xpath('//saml:SubjectConfirmationData', ns)['NotOnOrAfter'])
            .to eq(5.minutes.from_now.utc.iso8601)
          attrs = attribute_values(doc)
          expect(attrs['delegation_scopes']).to eq([expected_scope])
          expect(attrs['delegation_id']).to eq([grant.delegation_id])
          expect(attrs['first_name']).to eq(['Ada'])
          expect(attrs['dpop_jkt']).to eq([dpop_thumbprint]) if bound

          # The family's one issuance record is renewed; the new assertion is keyed to it.
          issued = TokenExchangeToken.sole
          expect(issued.refresh_count).to eq(1)
          expect(issued.token_format).to eq('saml2')
          expect(issued.token_type).to eq('N_A')
          expect(issued.refresh_family_id)
            .to eq(TokenExchangeRefreshToken.lookup(first[:refresh_token]).family_id)
          expect(DelegatedTokenStore.read(doc.root['ID'])).to include(issuance_id: issued.id)
          expect(DelegatedTokenStore.read(first_doc.root['ID'])).to be_present
          expect(TokenExchangeRefreshToken.lookup(first[:refresh_token])).to be_rotated
        end
      end

      it 'issues identifiers only once the service provider sign-in has ended' do
        OutOfBandSessionAccessor.new(rails_session_id).destroy

        body = refresh(first[:refresh_token])

        expect(response).to have_http_status(:ok)
        expect(body[:session_live]).to eq(false)
        expect(body[:scope]).to eq(expected_scope)
        doc, = decode_assertion(body[:access_token])
        attrs = attribute_values(doc)
        expect(attrs).not_to have_key('first_name')
        expect(attrs['email']).to eq([identity.email_address_for_sharing.email])
        expect(attrs['delegation_id']).to eq([grant.delegation_id])
      end

      it 'refuses once the approval has been revoked and ends the family' do
        grant.revoke!(reason: 'user_revoked')

        expect { refresh(first[:refresh_token]) }.not_to(change { TokenExchangeToken.count })
        expect(json[:error]).to eq('invalid_grant')
        expect(DelegatedTokenStore.read(first_doc.root['ID'])).to be_nil
      end
    end

    describe 'introspection by the agency API' do
      let!(:first) { exchange }
      let(:first_doc) { decode_assertion(first[:access_token]).first }
      let(:assertion_id) { first_doc.root['ID'] }

      it 'answers for the assertion ID read from the assertion' do
        body = introspect_as_agency(assertion_id)

        expect(response).to have_http_status(:ok)
        expect(body).to include(
          active: true,
          aud: resource_server.identifier,
          scope: expected_scope,
          client_id: service_provider.issuer,
          delegation_id: grant.delegation_id,
          token_type: 'N_A',
          sub: AgencyIdentity.find_by(user:, agency:).uuid,
          act: { sub: service_provider.issuer },
          jti: Digest::SHA256.hexdigest(assertion_id),
          given_name: 'Ada',
          family_name: 'Lovelace',
        )
        expect(body[:exp]).to eq(TokenExchangeToken.last.expires_at.to_i)
        if bound
          expect(body[:cnf]).to eq(jkt: dpop_thumbprint)
        else
          expect(body).not_to have_key(:cnf)
        end
      end

      it 'answers for the encoded assertion when it can read the ID, and not when encrypted' do
        expect(introspect_as_agency(first[:access_token])).to eq(active: false)

        xml = decode_assertion(first[:access_token]).last
        expect(introspect_as_agency(Base64.urlsafe_encode64(xml, padding: false)))
          .to include(active: true, jti: Digest::SHA256.hexdigest(assertion_id))
        expect(introspect_as_agency(Base64.strict_encode64(xml))).to include(active: true)
      end

      it 'answers not active once the assertion has expired' do
        travel 5.minutes do
          expect(introspect_as_agency(assertion_id)).to eq(active: false)
        end
      end
    end

    describe 'revocation' do
      let!(:first) { exchange }
      let(:first_doc) { decode_assertion(first[:access_token]).first }
      let(:assertion_id) { first_doc.root['ID'] }
      let(:issued) { TokenExchangeToken.last }

      it 'by assertion ID ends that assertion and leaves the family' do
        revoke(assertion_id)

        expect(response).to have_http_status(:ok)
        expect(response.body).to eq('{}')
        expect(DelegatedTokenStore.read(assertion_id)).to be_nil
        expect(issued.reload.revocation_reason).to eq('client_revoked')
        expect(TokenExchangeRefreshToken.lookup(first[:refresh_token]).revoked?).to eq(false)
        expect(introspect_as_agency(assertion_id)).to eq(active: false)
      end

      it 'by the encoded assertion ends it when the ID can be read' do
        xml = decode_assertion(first[:access_token]).last
        revoke(Base64.urlsafe_encode64(xml, padding: false))
        expect(response).to have_http_status(:ok)
        expect(DelegatedTokenStore.read(assertion_id)).to be_nil
        expect(issued.reload).to be_revoked
      end

      it 'by the encrypted encoded assertion is accepted and not acted on' do
        revoke(first[:access_token])
        expect(response).to have_http_status(:ok)
        expect(DelegatedTokenStore.read(assertion_id)).to be_present
        expect(issued.reload).not_to be_revoked
      end

      it 'by refresh token ends the whole family' do
        revoke(first[:refresh_token])
        expect(response).to have_http_status(:ok)
        expect(DelegatedTokenStore.read(assertion_id)).to be_nil
        expect(issued.reload.revocation_reason).to eq('client_revoked')
        expect(TokenExchangeRefreshToken.lookup(first[:refresh_token])).to be_revoked
      end
    end
  end

  context 'as a public client' do
    let(:service_provider) do
      create(
        :service_provider, :delegation_service_provider,
        issuer: 'urn:gov:gsa:openidconnect:sp:mybenefits',
        friendly_name: 'MyBenefits Assistant',
        pkce: true, certs: []
      )
    end
    let!(:identity) { link_identity(service_provider, dpop_jkt: dpop_thumbprint) }

    # `client_id` and a fresh proof for the endpoint, with `ath` over the token being presented.
    def authenticate(params, url:, token: nil)
      [
        params.merge(client_id: service_provider.issuer),
        { 'DPoP' => build_dpop_proof(url:, access_token: token) },
      ]
    end

    include_examples 'a SAML assertion exchange', bound: true

    describe 'introspection by the service provider itself' do
      let!(:first) { exchange }
      let(:assertion_id) { decode_assertion(first[:access_token]).first.root['ID'] }

      def introspect_as_service_provider(token, key: dpop_key)
        post api_openid_connect_introspect_path,
             params: { token:, client_id: service_provider.issuer },
             headers: {
               'DPoP' => build_dpop_proof(
                 url: api_openid_connect_introspect_url, access_token: token, key:,
               ),
             }
        json
      end

      it 'answers the limited response for the assertion ID with a proof from the bound key' do
        body = introspect_as_service_provider(assertion_id)
        expect(body).to include(
          active: true, token_type: 'N_A', cnf: { jkt: dpop_thumbprint }, scope: expected_scope,
        )
        expect(body.keys).not_to include(:act, :given_name, :family_name)
      end

      it 'answers not active with a proof from another key' do
        body = introspect_as_service_provider(
          assertion_id, key: OpenSSL::PKey::EC.generate('prime256v1')
        )
        expect(body).to eq(active: false)
      end
    end

    it 'refuses revocation of the assertion with a proof from another key' do
      first = exchange
      assertion_id = decode_assertion(first[:access_token]).first.root['ID']
      post api_openid_connect_revoke_path,
           params: { token: assertion_id, client_id: service_provider.issuer },
           headers: {
             'DPoP' => build_dpop_proof(
               url: api_openid_connect_revoke_url, access_token: assertion_id,
               key: OpenSSL::PKey::EC.generate('prime256v1')
             ),
           }
      expect(response).to have_http_status(:ok)
      expect(DelegatedTokenStore.read(assertion_id)).to be_present
    end
  end

  context 'as a confidential client' do
    let(:service_provider) do
      create(
        :service_provider, :delegation_service_provider,
        issuer: 'urn:gov:gsa:openidconnect:sp:mybenefits',
        friendly_name: 'MyBenefits Assistant',
        pkce: false, certs: ['saml_test_sp']
      )
    end
    let!(:identity) { link_identity(service_provider) }

    # A fresh client assertion for the endpoint; the token being presented does not enter it.
    def authenticate(params, url:, token: nil) # rubocop:disable Lint/UnusedMethodArgument
      [
        params.merge(
          client_assertion_type: OpenidConnectTokenForm::CLIENT_ASSERTION_TYPE,
          client_assertion: build_client_assertion(
            client_id: service_provider.issuer, audience: url,
          ),
        ),
        {},
      ]
    end

    include_examples 'a SAML assertion exchange', bound: false

    it 'issues the assertion when an access token is requested: the registration decides' do
      stub_request_analytics
      body = exchange(requested_token_type: OpenidConnectTokenExchangeForm::ACCESS_TOKEN_TYPE)

      expect(response).to have_http_status(:ok)
      expect(body[:issued_token_type]).to eq(OpenidConnectTokenExchangeForm::SAML2_TOKEN_TYPE)
      expect(body[:token_type]).to eq('N_A')
      expect(TokenExchangeToken.last.token_format).to eq('saml2')
      expect(@analytics).to have_logged_event(
        :openid_connect_token_exchange,
        hash_including(success: true, requested_token_type_mismatch: true),
      )
    end
  end
end
