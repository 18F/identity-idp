require 'rails_helper'

RSpec.describe OpenidConnectTokenForm do
  include Rails.application.routes.url_helpers

  subject(:form) { OpenidConnectTokenForm.new(params) }

  let(:params) do
    {
      client_assertion: client_assertion,
      client_assertion_type: client_assertion_type,
      code: code,
      code_verifier: code_verifier,
      dpop_proof: dpop_proof,
      grant_type: grant_type,
    }
  end

  let(:grant_type) { 'authorization_code' }
  let(:code) { identity.session_uuid }
  let(:code_verifier) { nil }
  let(:dpop_proof) { nil }
  let(:client_assertion_type) { OpenidConnectTokenForm::CLIENT_ASSERTION_TYPE }
  let(:client_assertion) { JWT.encode(jwt_payload, client_private_key, 'RS256') }

  let(:client_id) { service_provider.issuer }

  let(:service_provider) do
    create(
      :service_provider,
      certs: ['saml_test_sp2', 'saml_test_sp'],
    )
  end

  let(:nonce) { SecureRandom.hex }
  let(:code_challenge) { nil }
  let(:private_key_jwt_pkce) { false }
  let(:jwt_payload) do
    {
      iss: client_id,
      sub: client_id,
      aud: api_openid_connect_token_url,
      jti: SecureRandom.hex,
      exp: 5.minutes.from_now.to_i,
      iat: Time.zone.now.to_i,
    }
  end

  let(:client_private_key) do
    OpenSSL::PKey::RSA.new(Rails.root.join('keys', 'saml_test_sp.key').read)
  end
  let(:server_public_key) { Rails.application.config.oidc_public_key }

  let(:user) { create(:user) }

  let!(:identity) do
    IdentityLinker.new(user, service_provider)
      .link_identity(
        acr_values: Saml::Idp::Constants::IAL_AUTH_ONLY_ACR,
        nonce: nonce,
        rails_session_id: SecureRandom.hex,
        ial: 1,
        code_challenge: code_challenge,
        private_key_jwt_pkce: private_key_jwt_pkce,
      )
  end

  describe '#valid?' do
    subject(:valid?) { form.valid? }

    context 'with an incorrect grant_type' do
      let(:grant_type) { 'wrong' }

      it { expect(valid?).to eq(false) }
    end

    context 'code' do
      context 'with a bad code' do
        before { user.identities.delete_all }

        it 'is invalid' do
          expect(valid?).to eq(false)
          expect(form.errors[:code]).to include(t('openid_connect.token.errors.invalid_code'))
        end
      end

      context 'using the same code a second time' do
        before { OpenidConnectTokenForm.new(params).submit }

        it 'is invalid' do
          expect(valid?).to eq(false)
          expect(form.errors[:code]).to include(t('openid_connect.token.errors.invalid_code'))
        end
      end

      context 'the code has a null byte' do
        let(:code) { "\x00code" }

        it 'is invalid' do
          expect(valid?).to eq(false)
          expect(form.errors[:code]).to include(t('openid_connect.token.errors.invalid_code'))
        end
      end

      context 'code has expired' do
        before { identity.update(updated_at: 1.day.ago) }

        it 'is invalid' do
          expect(valid?).to eq(false)
          expect(form.errors[:code]).to eq([t('openid_connect.token.errors.expired_code')])
        end
      end

      context 'code expiration is independent of session timeout' do
        before do
          allow(IdentityConfig.store).to receive(
            :openid_connect_authorization_code_expiration_seconds,
          ).and_return(60)
          allow(IdentityConfig.store).to receive(
            :session_timeout_in_seconds,
          ).and_return(900)
          identity.update(updated_at: 2.minutes.ago)
        end

        it 'expires based on code expiration, not session timeout' do
          expect(valid?).to eq(false)
          expect(form.errors[:code]).to eq([t('openid_connect.token.errors.expired_code')])
        end
      end

      context 'code is nil' do
        before do
          # Create a service provider identity with a nil session uuid to make sure the form is not
          # looking up a service provider identity with a nil code and finding this one
          create(:service_provider_identity, session_uuid: nil)
        end

        let(:code) { nil }

        it 'is invalid' do
          expect(valid?).to eq(false)
          expect(form.errors[:code]).to include(t('openid_connect.token.errors.invalid_code'))
        end
      end
    end

    context 'private_key_jwt' do
      context 'with valid params' do
        it 'is true, and has no errors' do
          expect(valid?).to eq(true)
          expect(form.errors).to be_blank
        end

        it 'is true, and has no errors when the sp is set to jwt only mode' do
          allow_any_instance_of(ServiceProvider).to receive(:pkce).and_return(false)
          expect(valid?).to eq(true)
          expect(form.errors).to be_blank
        end

        it 'is false, and has errors if the sp is set for pkce only mode' do
          allow_any_instance_of(ServiceProvider).to receive(:pkce).and_return(true)
          expect(valid?).to eq(false)
          expect(form.errors[:code])
            .to include(t('openid_connect.token.errors.invalid_authentication'))
        end

        context 'with a trailing slash in the audience url' do
          before { jwt_payload[:aud] = 'http://www.example.com/api/openid_connect/token/' }

          it 'is valid' do
            expect(valid?).to eq(true)
          end
        end
      end

      context 'with a bad client_assertion_type' do
        let(:grant_type) { 'wrong' }

        it { expect(valid?).to eq(false) }
      end

      context 'with a bad client_assertion' do
        context 'without an audience' do
          before { jwt_payload.delete(:aud) }

          it 'is invalid' do
            expect(valid?).to eq(false)
            expect(form.errors[:client_assertion]).to include(
              t('openid_connect.token.errors.invalid_aud', url: api_openid_connect_token_url),
            )
          end
        end

        context 'with a bad audience' do
          before { jwt_payload[:aud] = 'https://foobar.com' }

          it 'is invalid' do
            expect(valid?).to eq(false)
            expect(form.errors[:client_assertion]).to include(
              t('openid_connect.token.errors.invalid_aud', url: api_openid_connect_token_url),
            )
          end
        end

        context 'with the old audience' do
          before { jwt_payload[:aud] = 'http://www.example.com/openid_connect/token' }

          it 'is invalid' do
            expect(valid?).to eq(false)
            expect(form.errors[:client_assertion]).to include(
              t('openid_connect.token.errors.invalid_aud', url: api_openid_connect_token_url),
            )
          end
        end

        context 'with a list of audiences including the token url' do
          before { jwt_payload[:aud] = [api_openid_connect_token_url] }

          it 'is valid' do
            expect(valid?).to eq(true)
          end
        end

        context 'with a list of audiences not including the token url' do
          before { jwt_payload[:aud] = ['a different audience'] }

          it 'is invalid' do
            expect(valid?).to eq(false)
            expect(form.errors[:client_assertion]).to include(
              t('openid_connect.token.errors.invalid_aud', url: api_openid_connect_token_url),
            )
          end
        end

        context 'with a bad issuer' do
          before { jwt_payload[:iss] = 'wrong' }

          it 'is invalid' do
            expect(valid?).to eq(false)
            expect(form.errors[:client_assertion])
              .to include("Invalid issuer. Expected [\"#{client_id}\"], received wrong")
          end
        end

        context 'with a bad subject' do
          before { jwt_payload[:sub] = 'wrong' }

          it 'is invalid' do
            expect(valid?).to eq(false)
            expect(form.errors[:client_assertion])
              .to include("Invalid subject. Expected #{client_id}, received wrong")
          end
        end

        context 'with an already expired assertion' do
          before { jwt_payload[:exp] = 5.minutes.ago.to_i }

          it 'is invalid' do
            expect(valid?).to eq(false)
            expect(form.errors[:client_assertion]).to include('Signature has expired')
          end
        end

        context 'with an issued time in the future' do
          before { jwt_payload[:iat] = Time.zone.now.to_i + 1.minute.to_i }

          it 'is invalid' do
            expect(valid?).to eq(false)
            expect(form.errors[:client_assertion]).to include(
              t('openid_connect.token.errors.invalid_iat'),
            )
          end
        end

        context 'with no issued time' do
          before { jwt_payload.except!(:iat) }

          it 'is still valid' do
            expect(valid?).to eq(true)
          end
        end

        context 'signed by a second key' do
          let(:client_private_key) do
            OpenSSL::PKey::RSA.new(Rails.root.join('keys', 'saml_test_sp2.key').read)
          end

          it 'is still valid' do
            expect(valid?).to eq(true)
          end
        end

        context 'service provider has no certs registered' do
          before do
            service_provider.certs = []
            service_provider.save!
          end

          it 'is has an error' do
            expect(valid?).to eq(false)
            expect(form.errors[:client_assertion])
              .to include(t('openid_connect.token.errors.invalid_signature'))
          end
        end

        context 'signed by an unknown key' do
          let(:client_private_key) { OpenSSL::PKey::RSA.new(2048) }

          it 'is invalid' do
            expect(valid?).to eq(false)
            expect(form.errors[:client_assertion]).to include('Signature verification failed')
          end
        end
      end
    end

    context 'with existing private_key_jwt challenge behavior' do
      let(:code_challenge) { 'previously-ignored-challenge' }

      before { service_provider.update!(pkce: false) }

      [nil, '', 'unrelated-verifier'].each do |verifier|
        context "with verifier #{verifier.inspect}" do
          let(:code_verifier) { verifier }

          it 'accepts the client assertion without enforcing the challenge' do
            expect(form.submit.success?).to eq(true)
          end
        end
      end
    end

    context 'with a legacy private_key_jwt code after enabling the flag' do
      let(:code_challenge) { 'previously-ignored-challenge' }

      before do
        service_provider.update!(pkce: false)
        allow(IdentityConfig.store).to receive(
          :openid_connect_private_key_jwt_pkce_enabled,
        ).and_return(true)
      end

      it 'does not require a verifier for a code issued without combined PKCE' do
        expect(form.submit.success?).to eq(true)
      end
    end

    context 'when a prefix is added to a legacy code' do
      let(:code) { 'pkce_' + identity.session_uuid }

      it 'rejects the altered code' do
        expect(valid?).to eq(false)
        expect(form.errors[:code]).to include(t('openid_connect.token.errors.invalid_code'))
      end
    end

    context 'PKCE' do
      let(:client_assertion) { nil }
      let(:client_assertion_type) { nil }

      let(:code_challenge) { Digest::SHA256.urlsafe_base64digest(code_verifier) }
      let(:code_verifier) { SecureRandom.hex }

      context 'with valid params' do
        it 'is true, and has no errors' do
          expect(valid?).to eq(true)
          expect(form.errors).to be_blank
        end

        it 'is true, and has no errors if the sp is set for pkce only mode' do
          allow_any_instance_of(ServiceProvider).to receive(:pkce).and_return(true)
          expect(valid?).to eq(true)
          expect(form.errors).to be_blank
        end

        it 'is false, and has errors if the sp is set for jwt only mode' do
          allow_any_instance_of(ServiceProvider).to receive(:pkce).and_return(false)
          expect(valid?).to eq(false)
          expect(form.errors[:code])
            .to include(t('openid_connect.token.errors.invalid_authentication'))
        end
      end

      context 'with a code_challenge that is not the SHA256 of the code_verifier' do
        let(:code_challenge) { 'aaa' }
        let(:code_verifier) { 'aaa' }

        it 'is not valid' do
          expect(valid?).to eq(false)
          expect(form.errors[:code_verifier])
            .to include(t('openid_connect.token.errors.invalid_code_verifier'))
        end
      end

      context 'with a code_challenge but a missing code_verifier' do
        let(:code_verifier) { nil }
        let(:code_challenge) { 'abcdef' }

        it 'is not valid' do
          expect(valid?).to eq(false)
          expect(form.errors[:code_verifier])
            .to include(t('openid_connect.token.errors.invalid_code_verifier'))
        end
      end

      context 'with a code_challenge does not have base64 padding' do
        let(:code_verifier) { SecureRandom.uuid }
        let(:code_challenge) { Digest::SHA256.urlsafe_base64digest(code_verifier) }

        it 'is valid' do
          expect(Digest::SHA256.base64digest(code_verifier)).to end_with('=')
          expect(code_verifier).to_not end_with('=')

          expect(valid?).to eq(true)
          expect(form.errors).to be_blank
        end
      end
    end

    context 'private_key_jwt with PKCE' do
      let(:private_key_jwt_pkce) { true }
      let(:code_verifier) { SecureRandom.urlsafe_base64(32) }
      let(:code_challenge) { Digest::SHA256.urlsafe_base64digest(code_verifier) }

      before { service_provider.update!(pkce: false) }

      it 'requires both proofs and succeeds even with admission disabled' do
        expect(IdentityConfig.store.openid_connect_private_key_jwt_pkce_enabled).to eq(false)
        expect(valid?).to eq(true)
      end

      context 'when the code prefix is removed' do
        let(:code) { identity.session_uuid.delete_prefix('pkce_') }

        it 'rejects the altered code without consuming the original' do
          original_code = identity.session_uuid
          expect(form.submit.success?).to eq(false)
          expect(form.errors[:code]).to include(t('openid_connect.token.errors.invalid_code'))
          expect(form.response).not_to have_key(:access_token)
          expect(identity.reload.session_uuid).to eq(original_code)
        end
      end

      context 'when the code prefix is changed' do
        let(:code) { identity.session_uuid.sub('pkce_', 'changed_') }

        it 'rejects the altered code' do
          expect(valid?).to eq(false)
          expect(form.errors[:code]).to include(t('openid_connect.token.errors.invalid_code'))
        end
      end

      context 'without an assertion' do
        let(:client_assertion) { nil }
        let(:client_assertion_type) { nil }

        it 'does not allow PKCE to replace client authentication' do
          expect(valid?).to eq(false)
          expect(form.errors[:client_assertion]).to be_present
        end
      end

      context 'with an invalid assertion' do
        let(:client_assertion) { 'invalid' }

        it 'rejects the request despite a valid verifier' do
          expect(valid?).to eq(false)
          expect(form.errors[:client_assertion]).to be_present
        end
      end

      context 'with an invalid assertion type' do
        let(:client_assertion_type) { 'invalid' }

        it 'rejects the request' do
          expect(valid?).to eq(false)
          expect(form.errors[:client_assertion_type]).to be_present
        end
      end

      [nil, '', 'a' * 43].each do |verifier|
        context "with missing or mismatched verifier #{verifier.inspect}" do
          let(:code_challenge) { Digest::SHA256.urlsafe_base64digest('b' * 43) }
          let(:code_verifier) { verifier }

          it 'rejects the request without issuing tokens or consuming the code' do
            original_code = identity.session_uuid
            expect(form.submit.success?).to eq(false)
            expect(form.response).to include(error: 'invalid_grant')
            expect(form.response).not_to have_key(:access_token)
            expect(identity.reload.session_uuid).to eq(original_code)
          end
        end
      end

      ['a' * 42, 'a' * 129, '+' * 43, 'a' * 43 + "\n"].each do |verifier|
        context "with malformed verifier #{verifier.inspect}" do
          let(:code_verifier) { verifier }

          it 'rejects even when the digest matches' do
            expect(valid?).to eq(false)
            expect(form.errors[:code_verifier]).to be_present
          end
        end
      end

      [43, 128].each do |length|
        context "with a #{length}-character verifier" do
          let(:code_verifier) { ('aZ09-._~' * 16).first(length) }

          it 'accepts the RFC verifier length boundary and alphabet' do
            expect(valid?).to eq(true)
          end
        end
      end

      context 'with a legacy integration and no assertion' do
        let(:private_key_jwt_pkce) { false }
        before { service_provider.update!(pkce: nil) }
        let(:client_assertion) { nil }
        let(:client_assertion_type) { nil }

        it 'preserves legacy PKCE authentication' do
          expect(valid?).to eq(true)
        end
      end

      context 'with a legacy integration and an invalid assertion' do
        let(:private_key_jwt_pkce) { false }
        before { service_provider.update!(pkce: nil) }
        let(:client_assertion) { 'invalid' }

        it 'does not skip a supplied assertion when the verifier is valid' do
          expect(valid?).to eq(false)
          expect(form.errors[:client_assertion]).to be_present
        end
      end

      context 'with a stored padded challenge' do
        let(:code_challenge) { Base64.urlsafe_encode64(Digest::SHA256.digest(code_verifier)) }

        it 'continues to verify previously issued challenges' do
          expect(valid?).to eq(true)
        end
      end

      context 'with no stored challenge' do
        let(:code_challenge) { nil }

        it 'rejects a marked transaction whose challenge is missing' do
          expect(valid?).to eq(false)
          expect(form.response).to include(error: 'invalid_grant')
        end
      end

      context 'with an expired code' do
        before { identity.update!(updated_at: 1.day.ago) }

        it 'rejects valid proofs for an expired code' do
          expect(valid?).to eq(false)
          expect(form.errors[:code]).to include(t('openid_connect.token.errors.expired_code'))
        end
      end

      it 'consumes the code on success and rejects replay' do
        request_params = params
        expect(form.submit.success?).to eq(true)
        expect(form.response[:access_token]).to be_present
        expect(identity.reload.session_uuid).to be_nil
        expect(OpenidConnectTokenForm.new(request_params).submit.success?).to eq(false)
      end
    end

    context 'neither PKCE nor private_key_jwt params' do
      let(:client_assertion) { nil }
      let(:client_assertion_type) { nil }
      let(:code_verifier) { nil }

      it 'is invalid' do
        expect(valid?).to eq(false)
        expect(form.errors[:code])
          .to include(t('openid_connect.token.errors.invalid_authentication'))
      end
    end
  end

  describe '#response' do
    context 'without delegation scopes in the request' do
      let(:code_verifier) { SecureRandom.hex }
      let(:code_challenge) { Digest::SHA256.urlsafe_base64digest(code_verifier) }
      let(:client_assertion) { nil }
      let(:client_assertion_type) { nil }

      it 'has no scope member' do
        expect(form.response.keys).to contain_exactly(
          :access_token, :token_type, :expires_in, :id_token
        )
      end
    end

    context 'when the request named applications for delegated access' do
      let(:code_verifier) { SecureRandom.hex }
      let(:code_challenge) { Digest::SHA256.urlsafe_base64digest(code_verifier) }
      let(:client_assertion) { nil }
      let(:client_assertion_type) { nil }
      let(:service_provider) { create(:service_provider, :delegation_service_provider, pkce: true) }
      # A public client approved for delegation: its code is bound to its DPoP key.
      let(:dpop_proof) { build_dpop_proof(url: api_openid_connect_token_url) }
      let(:user) { create(:user, :proofed) }
      let(:rails_session_id) { SecureRandom.hex }
      let!(:housing) do
        create(
          :service_provider, :delegation_application, delegation_scope_value: 'housing_records'
        )
      end
      let!(:retirement) do
        create(
          :service_provider, :delegation_application,
          delegation_scope_value: 'retirement_benefits'
        )
      end
      let!(:identity) do
        IdentityLinker.new(user, service_provider).link_identity(
          acr_values: Saml::Idp::Constants::IAL_VERIFIED_ACR,
          nonce: nonce,
          rails_session_id: rails_session_id,
          ial: 2,
          code_challenge: code_challenge,
          dpop_jkt: dpop_thumbprint,
          scope: 'openid email token_exchange:housing_records token_exchange:retirement_benefits',
        )
      end

      before { allow(IdentityConfig.store).to receive(:token_exchange_enabled).and_return(true) }

      def approve(application, remember:, rails_session_id: nil)
        TokenExchangeGrant.approve!(
          user:, service_provider:, application:, source: 'consent_screen', remember:,
          rails_session_id:
        )
      end

      it 'lists the attribute scopes and the approved delegation scopes, in request order' do
        approve(housing, remember: true)
        approve(retirement, remember: false, rails_session_id: rails_session_id)

        expect(form.response[:scope])
          .to eq('openid email token_exchange:housing_records token_exchange:retirement_benefits')
      end

      it 'omits an application the person did not approve' do
        approve(retirement, remember: true)

        expect(form.response[:scope]).to eq('openid email token_exchange:retirement_benefits')
      end

      it 'omits a single-authorization approval given in a different sign-in' do
        approve(housing, remember: false, rails_session_id: 'another-browser-session')

        expect(form.response[:scope]).to eq('openid email')
      end

      it 'omits an approval revoked after the consent screen' do
        approve(housing, remember: true).revoke!(reason: 'user_revoked')

        expect(form.response[:scope]).to eq('openid email')
      end

      it 'omits an approval made stale by a material content change' do
        approve(housing, remember: true)
        housing.update!(consent_content_version: 2, consent_material_version: 2)

        expect(form.response[:scope]).to eq('openid email')
      end
    end
  end

  describe '#submit' do
    context 'with valid params' do
      it 'returns FormResponse with success: true' do
        submission = form.submit

        expect(submission.to_h).to eq(
          success: true,
          client_id: client_id,
          user_id: user.uuid,
          code_digest: Digest::SHA256.hexdigest(code),
          code_verifier_present: false,
          service_provider_pkce: nil,
          ial: 1,
          integration_errors: nil,
        )
      end
    end

    context 'with invalid code' do
      let(:code) { nil }

      it 'returns FormResponse with success: false' do
        submission = form.submit

        expect(submission.to_h).to include(
          success: false,
          error_details: hash_including(*form.errors.attribute_names),
          client_id: nil,
          user_id: nil,
          code_digest: nil,
        )
      end
    end

    context 'with the wrong grant_type ' do
      let(:grant_type) { 'wrong' }

      it 'returns FormResponse with success: false and int error' do
        submission = form.submit

        expect(submission.to_h).to include(
          success: false,
          error_details: hash_including(:grant_type),
          client_id: client_id,
          user_id: user.uuid,
          code_digest: Digest::SHA256.hexdigest(code),
          code_verifier_present: false,
          service_provider_pkce: nil,
          ial: 1,
          integration_errors: {
            error_details: ['Grant type is not included in the list'],
            error_types: [:grant_type],
            event: :oidc_token_request,
            integration_exists: true,
            request_issuer: client_id,
          },
        )
      end
    end
  end

  describe '#response' do
    subject(:response) { form.response }

    context 'with valid params' do
      before do
        OutOfBandSessionAccessor.new(
          identity.rails_session_id,
        ).put_empty_user_session(
          5.minutes.in_seconds,
        )
      end

      it 'has a properly-encoded id_token with an expiration that matches the expires_in' do
        id_token = response[:id_token]

        payload, _head = JWT.decode(
          id_token, server_public_key, true,
          algorithm: 'RS256',
          iss: root_url, verify_iss: true,
          aud: client_id, verify_aud: true
        ).map(&:with_indifferent_access)

        expect(payload[:nonce]).to eq(nonce)

        expect(response[:expires_in]).to be_within(1).of(payload[:exp] - Time.zone.now.to_i)
      end

      it 'has an access_token' do
        expect(response[:access_token]).to eq(user.identities.last.access_token)
      end

      it 'specifies its token type' do
        expect(response[:token_type]).to eq('Bearer')
      end
    end

    context 'with invalid params' do
      let(:code) { nil }

      it 'has no id_token' do
        expect(response).to_not have_key(:id_token)
      end

      it 'has an error key in the response' do
        expect(response[:error]).to be_present
      end
    end
  end
end

RSpec.describe OpenidConnectTokenForm, 'for a public client approved for delegation' do
  include Rails.application.routes.url_helpers

  let(:service_provider) do
    create(:service_provider, :delegation_service_provider, pkce: true, certs: [])
  end
  let(:user) { create(:user) }
  let(:code_verifier) { SecureRandom.urlsafe_base64(32) }
  let(:code_challenge) { Digest::SHA256.urlsafe_base64digest(code_verifier) }
  let(:stored_thumbprint) { dpop_thumbprint }
  let!(:identity) do
    IdentityLinker.new(user, service_provider).link_identity(
      acr_values: Saml::Idp::Constants::IAL_AUTH_ONLY_ACR,
      nonce: SecureRandom.hex,
      rails_session_id: SecureRandom.hex,
      ial: 1,
      code_challenge:,
      dpop_jkt: stored_thumbprint,
    )
  end
  let(:dpop_proof) { build_dpop_proof(url: api_openid_connect_token_url) }
  let(:params) do
    { grant_type: 'authorization_code', code: identity.session_uuid, code_verifier:, dpop_proof: }
  end

  subject(:form) { OpenidConnectTokenForm.new(params) }

  before do
    allow(IdentityConfig.store).to receive(:token_exchange_enabled).and_return(true)
    OutOfBandSessionAccessor.new(identity.rails_session_id).put_empty_user_session(300)
  end

  it 'redeems the code with a proof from the bound key and issues a DPoP token' do
    expect(form.valid?).to eq(true)
    response = form.response
    expect(response[:token_type]).to eq('DPoP')
    expect(response[:access_token]).to eq(identity.access_token)
    expect(response[:id_token]).to be_present
  end

  context 'without a proof' do
    let(:dpop_proof) { nil }

    it 'fails with invalid_dpop_proof and leaves the code redeemable' do
      expect(form.submit.success?).to eq(false)
      expect(form.response).to eq(
        error: 'invalid_dpop_proof',
        error_description: t('openid_connect.token.errors.dpop_proof_required'),
      )
      expect(identity.reload.session_uuid).to be_present
    end
  end

  context 'with a proof from a key other than the one named at authorization' do
    let(:dpop_proof) do
      build_dpop_proof(url: api_openid_connect_token_url, key: OpenSSL::PKey::EC.generate('prime256v1'))
    end

    it 'fails with invalid_dpop_proof' do
      expect(form.valid?).to eq(false)
      expect(form.response[:error]).to eq('invalid_dpop_proof')
      expect(form.response[:error_description])
        .to eq(t('openid_connect.token.errors.dpop_key_mismatch'))
    end
  end

  context 'with a proof for a different URL' do
    let(:dpop_proof) { build_dpop_proof(url: api_openid_connect_userinfo_url) }

    it 'fails with invalid_dpop_proof' do
      expect(form.valid?).to eq(false)
      expect(form.response[:error]).to eq('invalid_dpop_proof')
    end
  end

  context 'when the code was issued without a thumbprint' do
    let(:stored_thumbprint) { nil }

    it 'fails with invalid_dpop_proof naming the missing binding' do
      expect(form.valid?).to eq(false)
      expect(form.response[:error_description])
        .to eq(t('openid_connect.token.errors.dpop_code_unbound'))
    end
  end

  context 'when the code verifier is wrong' do
    let(:params) do
      {
        grant_type: 'authorization_code',
        code: identity.session_uuid,
        code_verifier: 'wrong',
        dpop_proof:,
      }
    end

    it 'reports the verifier error, not a proof error, and does not consume the proof jti' do
      expect(form.valid?).to eq(false)
      expect(form.errors.attribute_names).to eq([:code_verifier])
      expect(
        DpopProofVerifier.new(
          proof: dpop_proof, http_method: 'POST', http_url: api_openid_connect_token_url,
        ).call,
      ).to be_success
    end
  end

  context 'for a public client that is not approved for delegation' do
    before { service_provider.update!(token_exchange_enabled_sp: false) }
    let(:dpop_proof) { nil }

    it 'issues a bearer token without a proof, as before' do
      expect(form.valid?).to eq(true)
      expect(form.response[:token_type]).to eq('Bearer')
    end
  end
end
