require 'rails_helper'

RSpec.describe OpenidConnectTokenExchangeForm do
  subject(:form) { described_class.new(params) }

  let(:broker) { create(:service_provider, :active, issuer: 'broker-issuer') }
  let(:broker_issuer) { broker.issuer }
  let(:client_id) { broker_issuer }
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
      service_provider: broker_issuer,
      scope: scope,
      ial: 2,
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
  let(:scope) { 'openid token_exchange:passport' }
  let(:actor_return_log) do
    create(
      :sp_return_log,
      user:, issuer: broker_issuer, ial: 2, billable: true, returned_at: Time.zone.now,
    )
  end
  let(:subject_token) do
    TokenExchange::SubjectTokenIssuer.issue(
      identity:, actor_return_log_id: actor_return_log.id,
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
    }
  end

  before do
    allow(IdentityConfig.store).to receive(:token_exchange_enabled).and_return(true)
    allow(IdentityConfig.store).to receive(:token_exchange_allowed_broker_issuers)
      .and_return([broker_issuer])
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

    context 'when the broker is not allowlisted' do
      before do
        allow(IdentityConfig.store).to receive(:token_exchange_allowed_broker_issuers)
          .and_return([])
      end

      it 'is invalid' do
        expect(form.submit.success?).to eq(false)
        expect(form.errors[:client_id]).to include('is invalid')
      end

      it 'does not read the subject token from Redis' do
        expect(TokenExchange::SubjectToken).to_not receive(:load)

        form.submit
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

      it 'does not read the subject token from Redis' do
        expect(TokenExchange::SubjectToken).to_not receive(:load)

        form.submit
      end
    end

    context 'when the subject token belongs to another broker' do
      let(:other_broker) { create(:service_provider, :active, issuer: 'other-broker-issuer') }
      let(:client_id) { other_broker.issuer }

      before do
        allow(IdentityConfig.store).to receive(:token_exchange_allowed_broker_issuers)
          .and_return([broker_issuer, other_broker.issuer])
      end

      it 'is invalid' do
        expect(form.submit.success?).to eq(false)
        expect(form.errors[:subject_token]).to include('is invalid')
      end
    end

    context 'when the subject token was not issued at IAL2' do
      before do
        identity.update!(ial: 1)
      end

      it 'is invalid' do
        expect(form.submit.success?).to eq(false)
        expect(form.errors[:subject_token]).to include('is invalid')
      end
    end

    context 'when the user is no longer identity verified' do
      before do
        subject_token
        user.active_profile.deactivate(:password_reset)
      end

      it 'is invalid' do
        expect(form.submit.success?).to eq(false)
        expect(form.errors[:subject_token]).to include('is invalid')
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
        actor_issuer: broker_issuer,
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

    context 'when the broker is not allowlisted' do
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

    context 'with requested scope outside the subject token scope' do
      let(:params) { super().merge(scope: 'openid token_exchange:benefits') }

      it 'returns invalid_scope' do
        expect(error).to eq('invalid_scope')
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
