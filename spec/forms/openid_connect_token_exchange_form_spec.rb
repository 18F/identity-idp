require 'rails_helper'

RSpec.describe OpenidConnectTokenExchangeForm do
  include Rails.application.routes.url_helpers

  subject(:form) { described_class.new(params) }

  let(:actor) { create(:service_provider, :active, issuer: 'actor-issuer') }
  let(:actor_issuer) { actor.issuer }
  let(:client_id) { actor_issuer }
  let(:target) { create(:service_provider, :active, issuer: 'target-issuer') }
  let(:target_issuer) { target.issuer }
  let(:audience) { target_issuer }
  let(:user) { create(:user, :proofed) }
  let(:resource) { 'https://api.example.gov/passport' }
  let(:subject_token_type) { TokenExchange::Constants::ACCESS_TOKEN_TYPE }
  let(:grant_type) { TokenExchange::Constants::GRANT_TYPE }
  let(:requested_token_type) { TokenExchange::Constants::ACCESS_TOKEN_TYPE }
  let(:identity) do
    create(
      :service_provider_identity,
      user:,
      service_provider: actor_issuer,
      scope: scope,
      ial: 1,
    )
  end
  let!(:target_identity) do
    create(
      :service_provider_identity,
      user:,
      service_provider: target_issuer,
      scope: scope,
      ial: 2,
    )
  end
  let!(:sts_consent) { create(:user_consent_sts, user:, target_app: target_issuer) }
  let(:scope) { 'openid token_exchange:passport' }
  let(:actor_return_log) do
    create(
      :sp_return_log,
      user:, issuer: actor_issuer, ial: 2, billable: true, returned_at: Time.zone.now,
    )
  end
  let(:actor_return_log_id) { actor_return_log.id }
  let(:subject_token) do
    TokenExchange::SubjectTokenIssuer.issue(
      identity:, actor_return_log_id:,
    ).token
  end
  let(:params) do
    {
      client_id:,
      grant_type:,
      subject_token:,
      subject_token_type:,
      audience:,
      resource:,
      requested_token_type:,
      scope:,
      dpop_proof:,
      token_url: api_openid_connect_token_url,
    }
  end
  let(:dpop_proof) { nil }

  before do
    allow(IdentityConfig.store).to receive(:token_exchange_enabled).and_return(true)
    allow(IdentityConfig.store).to receive(:token_exchange_allowed_broker_issuers)
      .and_return([actor_issuer])
    allow(IdentityConfig.store).to receive(:token_exchange_allowed_targets)
      .and_return([{ issuer: target_issuer, scope: 'passport' }])
  end

  describe '#submit' do
    it 'returns success for a valid token exchange request' do
      expect(form.submit.success?).to eq(true)
    end

    it 'surfaces delegated token exchange analytics fields' do
      expect(form.submit.to_h).to include(
        token_exchange_stage: 'delegated_token',
        token_exchange_scopes: ['passport'],
        subject_token_fingerprint: TokenExchange::SubjectToken.digest(subject_token),
        oauth_error_code: nil,
      )
    end

    %i[
      client_id
      grant_type
      subject_token
      subject_token_type
      audience
      resource
      requested_token_type
    ].each do |attribute|
      context "with missing #{attribute}" do
        let(attribute) { nil }

        it 'is invalid' do
          expect(form.submit.success?).to eq(false)
          expect(form.errors[attribute]).to include('Please fill in this field.')
        end
      end
    end

    context 'when token exchange is disabled' do
      before do
        allow(IdentityConfig.store).to receive(:token_exchange_enabled).and_return(false)
      end

      it 'is invalid' do
        expect(form.submit.success?).to eq(false)
        expect(form.errors[:grant_type]).to include('is not included in the list')
      end
    end

    context 'with an unsupported grant type' do
      let(:grant_type) { 'authorization_code' }

      it 'is invalid' do
        expect(form.submit.success?).to eq(false)
        expect(form.errors[:grant_type]).to include('is not included in the list')
      end
    end

    context 'with an unsupported subject token type' do
      let(:subject_token_type) { 'urn:ietf:params:oauth:token-type:jwt' }

      it 'is invalid' do
        expect(form.submit.success?).to eq(false)
        expect(form.errors[:subject_token_type]).to include('is not included in the list')
      end
    end

    context 'with an unsupported requested token type' do
      let(:requested_token_type) { 'urn:ietf:params:oauth:token-type:jwt' }

      it 'is invalid' do
        expect(form.submit.success?).to eq(false)
        expect(form.errors[:requested_token_type]).to include('is not included in the list')
      end
    end

    context 'with a non-HTTPS resource' do
      let(:resource) { 'http://api.example.gov/passport' }

      it 'is invalid' do
        expect(form.submit.success?).to eq(false)
        expect(form.errors[:resource]).to include('is invalid')
      end

      it 'surfaces OAuth error code and failure reason' do
        expect(form.submit.to_h).to include(
          token_exchange_stage: 'delegated_token',
          subject_token_fingerprint: TokenExchange::SubjectToken.digest(subject_token),
          oauth_error_code: 'invalid_target',
        )
      end
    end

    context 'with requested scope outside the subject token scope' do
      let(:params) { super().merge(scope: 'openid token_exchange:benefits') }

      it 'is invalid' do
        expect(form.submit.success?).to eq(false)
        expect(form.errors[:scope]).to include('is invalid')
      end
    end

    context 'when the request omits scope' do
      let(:scope) { nil }

      it 'uses the subject token scope' do
        form.submit
        expect(form.response[:scope]).to eq(scope)
      end
    end

    context 'with an unknown subject token' do
      let(:subject_token) { 'unknown' }

      it 'is invalid' do
        expect(form.submit.success?).to eq(false)
        expect(form.errors[:subject_token]).to include('is invalid')
      end

      it 'does not repeatedly load the missing token' do
        expect(TokenExchange::SubjectToken).to receive(:load).once.and_call_original

        form.submit
        form.response
      end
    end

    context 'when the actor is not allowlisted' do
      before do
        allow(IdentityConfig.store).to receive(:token_exchange_allowed_broker_issuers)
          .and_return([])
      end

      it 'is invalid' do
        expect(form.submit.success?).to eq(false)
        expect(form.errors[:client_id]).to include('is invalid')
      end
    end

    context 'when the target is not allowlisted' do
      before do
        allow(IdentityConfig.store).to receive(:token_exchange_allowed_targets)
          .and_return([])
      end

      it 'is invalid' do
        expect(form.submit.success?).to eq(false)
        expect(form.errors[:audience]).to include('is invalid')
      end
    end

    context 'when the subject token belongs to another actor' do
      let(:other_actor) { create(:service_provider, :active, issuer: 'other-actor-issuer') }
      let(:client_id) { other_actor.issuer }

      before do
        allow(IdentityConfig.store).to receive(:token_exchange_allowed_broker_issuers)
          .and_return([actor_issuer, other_actor.issuer])
      end

      it 'is invalid' do
        expect(form.submit.success?).to eq(false)
        expect(form.errors[:subject_token]).to include('is invalid')
      end
    end

    context 'when the person has no delegation consent for the target' do
      before { sts_consent.destroy! }

      it 'is invalid on the audience' do
        expect(form.submit.success?).to eq(false)
        expect(form.errors.details[:audience]).to include(error: :no_delegation_consent)
        expect(form.errors.details[:subject_token]).to be_empty
      end
    end

    context 'when the delegation consent has expired' do
      before do
        sts_consent.update!(created_at: (UserConsentSts.consent_expiration + 1.day).ago)
      end

      it 'is invalid on the audience' do
        expect(form.submit.success?).to eq(false)
        expect(form.errors.details[:audience]).to include(error: :no_delegation_consent)
      end
    end

    context 'when the subject token has no originating actor return log' do
      let(:actor_return_log_id) { nil }

      it 'is invalid' do
        expect(form.submit.success?).to eq(false)
        expect(form.errors[:actor_return_log]).to include('Please fill in this field.')
      end
    end

    context 'when the originating actor return log belongs to another user' do
      let(:other_user) { create(:user) }
      let(:actor_return_log) do
        create(
          :sp_return_log,
          user: other_user,
          issuer: actor_issuer,
          ial: 2,
          billable: true,
          returned_at: Time.zone.now,
        )
      end

      it 'is invalid' do
        expect(form.submit.success?).to eq(false)
        expect(form.errors[:actor_return_log]).to include('Please fill in this field.')
      end
    end

    context 'when the originating actor return log belongs to another issuer' do
      let(:actor_return_log) do
        create(
          :sp_return_log,
          user:,
          issuer: 'other-actor-issuer',
          ial: 2,
          billable: true,
          returned_at: Time.zone.now,
        )
      end

      it 'is invalid' do
        expect(form.submit.success?).to eq(false)
        expect(form.errors[:actor_return_log]).to include('Please fill in this field.')
      end
    end

    context 'when the target identity is not IAL2' do
      before do
        target_identity.update!(ial: 1)
      end

      it 'is invalid' do
        expect(form.submit.success?).to eq(false)
        expect(form.errors[:audience]).to include('invalid identity assurance')
      end
    end

    context 'when the user does not have an identity on the target aud' do
      before { target_identity.destroy! }

      it 'is invalid' do
        expect(form.submit.success?).to eq(false)
        expect(form.errors[:audience]).to include('no identity')
      end
    end

    context 'when the user is no longer identity verified' do
      before do
        subject_token
        user.active_profile.deactivate(:password_reset)
      end

      it 'is invalid' do
        expect(form.submit.success?).to eq(false)
        expect(form.errors[:audience]).to include('no active profile')
      end

      it 'does not issue a delegated access token' do
        expect(TokenExchange::AccessTokenIssuer).to_not receive(:issue)

        form.submit
        form.response
      end
    end

    context 'when the user no longer exists' do
      before do
        subject_token
        user.destroy!
      end

      it 'is invalid' do
        expect(form.submit.success?).to eq(false)
        expect(form.errors[:subject_token]).to include('is invalid')
      end
    end
    context 'for an actor registered for key binding' do
      let(:target_private_key) do
        OpenSSL::PKey::RSA.new(Rails.root.join('keys', 'saml_test_sp.key').read)
      end
      let(:subject_token) do
        TokenExchange::SubjectTokenIssuer.issue(
          identity:, actor_return_log_id: actor_return_log.id, dpop_jkt: dpop_thumbprint,
        ).token
      end
      let(:dpop_proof) do
        build_dpop_proof(http_url: api_openid_connect_token_url, access_token: subject_token)
      end
      let(:decoded_token) do
        jwt = JWE.decrypt(form.response[:access_token], target_private_key)
        JWT.decode(
          jwt, Rails.application.config.oidc_public_key, true,
          algorithm: IdTokenBuilder::JWT_SIGNING_ALGORITHM
        ).first
      end

      before do
        actor.update!(pkce: true)
        allow(IdentityConfig.store).to receive(:dpop_required_issuers).and_return([actor_issuer])
      end

      context 'with a proof from the key the subject token is bound to' do
        before { form.submit }

        it 'is successful' do
          expect(form.submit.success?).to eq(true)
        end

        it 'issues the token under the DPoP scheme' do
          expect(form.response[:token_type]).to eq('DPoP')
        end

        it 'responds with a JWT encrypted to the target, signed by Login.gov, carrying cnf.jkt' do
          expect(decoded_token['cnf']).to eq('jkt' => dpop_thumbprint)
        end

        it 'records the thumbprint on the token' do
          token = TokenExchange::AccessToken.load(form.response[:access_token])
          expect(token.dpop_jkt).to eq(dpop_thumbprint)
        end

        it 'reports the binding on the analytics attributes' do
          expect(form.submit.extra[:dpop_bound]).to eq(true)
        end
      end

      context 'without a proof' do
        let(:dpop_proof) { nil }

        it 'responds with an invalid_dpop_proof error naming the missing proof' do
          expect(form.submit.success?).to eq(false)
          expect(form.response).to eq(
            error: 'invalid_dpop_proof',
            error_description: 'dpop_proof_missing',
          )
        end

        it 'reports the failed check in the error details' do
          expect(form.submit.to_h[:error_details]).to eq(dpop_proof: { dpop_proof_missing: true })
        end
      end

      context 'with a proof signed by a key other than the one the subject token is bound to' do
        let(:dpop_proof) do
          build_dpop_proof(
            http_url: api_openid_connect_token_url, access_token: subject_token,
            key: OpenSSL::PKey::EC.generate('prime256v1')
          )
        end

        it 'responds with an invalid_dpop_proof error naming the key mismatch' do
          expect(form.submit.success?).to eq(false)
          expect(form.response[:error_description]).to eq('dpop_key_mismatch')
        end
      end

      context 'with a proof that does not carry the hash of the subject token' do
        let(:dpop_proof) { build_dpop_proof(http_url: api_openid_connect_token_url) }

        it 'responds with an invalid_dpop_proof error' do
          expect(form.submit.success?).to eq(false)
          expect(form.response[:error]).to eq('invalid_dpop_proof')
        end
      end

      context 'when the subject token was issued without a binding' do
        let(:subject_token) do
          TokenExchange::SubjectTokenIssuer.issue(
            identity:, actor_return_log_id: actor_return_log.id,
          ).token
        end

        it 'responds with an invalid_dpop_proof error naming the unbound subject token' do
          expect(form.submit.success?).to eq(false)
          expect(form.response[:error_description]).to eq('dpop_subject_token_unbound')
        end
      end

      context 'when the request fails an earlier check' do
        let(:audience) { 'unknown-issuer' }

        it 'does not verify the proof, so its jti is not consumed' do
          expect(DpopProofForm).not_to receive(:new)
          expect(form.submit.success?).to eq(false)
          expect(form.response[:error]).to eq('invalid_target')
        end
      end
    end

    context 'for an actor not registered for key binding' do
      let(:dpop_proof) { 'not-read' }

      it 'ignores a DPoP header and issues a bearer token without cnf' do
        expect(DpopProofForm).not_to receive(:new)
        expect(form.submit.success?).to eq(true)
        expect(form.response[:token_type]).to eq('Bearer')
        expect(form.submit.extra[:dpop_bound]).to eq(false)

        jwt = JWE.decrypt(
          form.response[:access_token],
          OpenSSL::PKey::RSA.new(Rails.root.join('keys', 'saml_test_sp.key').read),
        )
        payload = JWT.decode(
          jwt, Rails.application.config.oidc_public_key, true,
          algorithm: IdTokenBuilder::JWT_SIGNING_ALGORITHM
        ).first
        expect(payload).not_to have_key('cnf')
      end
    end
  end

  describe '#response' do
    subject(:response) { form.response }

    it 'returns an opaque delegated access token response' do
      expect(response).to include(
        access_token: be_present,
        issued_token_type: requested_token_type,
        token_type: 'Bearer',
        expires_in: 600,
        scope:,
      )
    end

    it 'stores delegated access token metadata in Redis' do
      access_token = TokenExchange::AccessToken.load(response[:access_token])

      expect(access_token).to have_attributes(
        identity_uuid: target_identity.uuid,
        target_issuer:,
        resource:,
        scope:,
      )
    end

    it 'creates a billable target return log and historical issuance for every DAT' do
      expect { response }
        .to change { SpReturnLog.where(issuer: target_issuer).count }.by(1)
        .and change { user.delegated_issuance_logs.count }.by(1)

      issuance = user.delegated_issuance_logs.last
      expect(issuance).to have_attributes(
        actor_return_log_id: actor_return_log.id,
        actor_issuer: actor_issuer,
        target_issuer:,
        resource:,
        scope:,
      )
      expect(issuance.target_return_log).to have_attributes(
        issuer: target_issuer,
        billable: true,
        user_id: user.id,
      )
    end

    it 'exposes the historical issuance delegation id' do
      response

      expect(form.delegation_id).to eq(user.delegated_issuance_logs.last.delegation_id)
    end

    it 'creates distinct historical issuances for repeated DAT mints to the same target' do
      response
      described_class.new(params).response

      expect(user.delegated_issuance_logs.count).to eq(2)
      expect(user.delegated_issuance_logs.pluck(:delegation_id).uniq.count).to eq(2)
    end

    context 'when the subject token has no originating actor return log' do
      let(:subject_token) { TokenExchange::SubjectTokenIssuer.issue(identity:).token }

      it 'rejects the exchange and writes no issuance or target return log' do
        expect { expect(response[:error]).to eq('invalid_grant') }
          .to change { DelegatedIssuanceLog.count }.by(0)
          .and change { SpReturnLog.where(issuer: target_issuer).count }.by(0)
      end
    end

    context 'when invalid' do
      let(:subject_token) { 'unknown' }

      it 'returns an OAuth error response' do
        expect(response).to include(error: 'invalid_grant')
        expect(response[:error_description]).to be_present
      end
    end

    context 'when the person has no identity at the target' do
      before { target_identity.destroy! }

      context 'and the target entry carries a login-initiation address' do
        before do
          allow(IdentityConfig.store).to receive(:token_exchange_allowed_targets).and_return(
            [{
              issuer: target_issuer,
              scope: 'passport',
              initiate_login_uri: 'https://records.example.gov/initiate_login',
            }],
          )
        end

        it 'refuses with invalid_target and tells the actor where the person signs in' do
          expect(response).to include(
            error: 'invalid_target',
            initiate_login_uri: 'https://records.example.gov/initiate_login',
          )
          expect(response[:error_description]).to include('no identity')
        end
      end

      context 'and the target entry carries no login-initiation address' do
        it 'refuses with invalid_target and no address' do
          expect(response).to include(error: 'invalid_target')
          expect(response).not_to have_key(:initiate_login_uri)
        end
      end
    end

    context 'when the person has no delegation consent for the target' do
      before do
        sts_consent.destroy!
        allow(IdentityConfig.store).to receive(:token_exchange_allowed_targets).and_return(
          [{
            issuer: target_issuer,
            scope: 'passport',
            initiate_login_uri: 'https://records.example.gov/initiate_login',
          }],
        )
      end

      it 'refuses with invalid_target and names the scope to request on a sign-in' do
        expect(response).to eq(
          error: 'invalid_target',
          error_description: 'no_delegation_consent',
          scope: 'token_exchange:passport',
        )
      end

      it 'writes no issuance or target return log' do
        expect { response }
          .to change { DelegatedIssuanceLog.count }.by(0)
          .and change { SpReturnLog.where(issuer: target_issuer).count }.by(0)
      end
    end

    context 'when the refusal is not about a missing identity' do
      let(:subject_token) { 'unknown' }

      before do
        allow(IdentityConfig.store).to receive(:token_exchange_allowed_targets).and_return(
          [{
            issuer: target_issuer,
            scope: 'passport',
            initiate_login_uri: 'https://records.example.gov/initiate_login',
          }],
        )
      end

      it 'does not tell the actor the address' do
        expect(response[:error]).to eq('invalid_grant')
        expect(response).not_to have_key(:initiate_login_uri)
      end
    end
  end

  describe 'OAuth error codes' do
    subject(:error) { form.response[:error] }

    context 'when a required parameter is missing' do
      %i[
        client_id
        grant_type
        subject_token
        subject_token_type
        audience
        resource
        requested_token_type
      ].each do |attribute|
        context "with missing #{attribute}" do
          let(attribute) { nil }

          it 'returns invalid_request' do
            expect(error).to eq('invalid_request')
          end

          it 'returns a 400' do
            expect(form.http_status).to eq(:bad_request)
          end
        end
      end
    end

    context 'with an unsupported grant type' do
      let(:grant_type) { 'authorization_code' }

      it 'returns unsupported_grant_type' do
        expect(error).to eq('unsupported_grant_type')
      end

      it 'returns a 400' do
        expect(form.http_status).to eq(:bad_request)
      end
    end

    context 'when the actor is not allowlisted' do
      before do
        allow(IdentityConfig.store).to receive(:token_exchange_allowed_broker_issuers)
          .and_return([])
      end

      it 'returns invalid_client' do
        expect(error).to eq('invalid_client')
      end

      it 'returns a 401' do
        expect(form.http_status).to eq(:unauthorized)
      end
    end

    context 'when the target is not allowlisted' do
      before do
        allow(IdentityConfig.store).to receive(:token_exchange_allowed_targets)
          .and_return([])
      end

      it 'returns invalid_target' do
        expect(error).to eq('invalid_target')
      end

      it 'returns a 400' do
        expect(form.http_status).to eq(:bad_request)
      end
    end

    context 'with a non-HTTPS resource' do
      let(:resource) { 'http://api.example.gov/passport' }

      it 'returns invalid_target' do
        expect(error).to eq('invalid_target')
      end
    end

    context 'when the person has no delegation consent for the target' do
      before { sts_consent.destroy! }

      it 'returns invalid_target' do
        expect(error).to eq('invalid_target')
      end

      it 'returns a 400' do
        expect(form.http_status).to eq(:bad_request)
      end
    end

    context 'with requested scope outside the subject token scope' do
      let(:params) { super().merge(scope: 'openid token_exchange:benefits') }

      it 'returns invalid_scope' do
        expect(error).to eq('invalid_scope')
      end

      it 'returns a 400' do
        expect(form.http_status).to eq(:bad_request)
      end
    end

    context 'when a key-bound actor sends no proof' do
      before do
        actor.update!(pkce: true)
        allow(IdentityConfig.store).to receive(:dpop_required_issuers).and_return([actor_issuer])
      end
      let(:subject_token) do
        TokenExchange::SubjectTokenIssuer.issue(
          identity:, actor_return_log_id: actor_return_log.id, dpop_jkt: dpop_thumbprint,
        ).token
      end

      it 'is invalid_dpop_proof' do
        expect(error).to eq('invalid_dpop_proof')
      end

      it 'returns a 400' do
        expect(form.http_status).to eq(:bad_request)
      end
    end

    context 'with an unknown subject token' do
      let(:subject_token) { 'unknown' }

      it 'returns invalid_grant' do
        expect(error).to eq('invalid_grant')
      end

      it 'returns a 400' do
        expect(form.http_status).to eq(:bad_request)
      end
    end

    context 'when the request is valid' do
      it 'returns a 200' do
        expect(form.http_status).to eq(:ok)
      end
    end
  end
end
