require 'rails_helper'

RSpec.describe 'OpenID Connect token endpoint' do
  describe 'POST /api/openid_connect/token' do
    context 'with a DPoP header' do
      it 'hands the proof to the form from the header, never from the body' do
        expect(OpenidConnectTokenForm).to receive(:new)
          .with(hash_including(dpop_proof: 'proof-from-header', grant_type: 'authorization_code'))
          .and_call_original

        post api_openid_connect_token_path,
             params: { grant_type: 'authorization_code', code: 'x', dpop_proof: 'from-body' },
             headers: { 'DPoP' => 'proof-from-header' }
      end
    end

    context 'with token exchange grant type' do
      let(:client_id) { 'broker-issuer' }
      let(:audience) { 'target-issuer' }
      let(:resource) { 'https://api.example.gov/passport' }
      let(:params) do
        {
          grant_type: TokenExchange::Constants::GRANT_TYPE,
          subject_token: 'subject-token',
          subject_token_type: TokenExchange::Constants::ACCESS_TOKEN_TYPE,
          requested_token_type: TokenExchange::Constants::ACCESS_TOKEN_TYPE,
          client_id:,
          audience:,
          resource:,
        }
      end

      let(:extra) do
        {
          actor_issuer: client_id,
          target_issuer: audience,
          resource:,
          ial: 2,
        }
      end

      before do
        form = instance_double(
          OpenidConnectTokenExchangeForm,
          submit: FormResponse.new(success: true, errors: {}, extra:),
          response: {
            access_token: 'access-token',
            issued_token_type: TokenExchange::Constants::ACCESS_TOKEN_TYPE,
            token_type: 'Bearer',
            expires_in: 600,
          },
          delegation_id: nil,
        )
        allow(OpenidConnectTokenExchangeForm).to receive(:new).and_return(form)
        allow(form).to receive(:http_status).and_return(:ok)
      end

      it 'dispatches to the token exchange form' do
        post api_openid_connect_token_path, params: params

        expect(OpenidConnectTokenExchangeForm).to have_received(:new) do |token_params|
          expect(token_params[:grant_type]).to eq(TokenExchange::Constants::GRANT_TYPE)
          expect(token_params[:subject_token]).to eq('subject-token')
          expect(token_params[:client_id]).to eq(client_id)
          expect(token_params[:audience]).to eq(audience)
          expect(token_params[:resource]).to eq(resource)
        end
      end
    end
  end
end
