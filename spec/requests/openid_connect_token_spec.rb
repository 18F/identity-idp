require 'rails_helper'

RSpec.describe 'OpenID Connect token endpoint' do
  describe 'POST /api/openid_connect/token' do
    context 'with token exchange grant type' do
      let(:params) do
        {
          grant_type: TokenExchange::Constants::GRANT_TYPE,
          subject_token: 'subject-token',
          subject_token_type: TokenExchange::Constants::ACCESS_TOKEN_TYPE,
          requested_token_type: TokenExchange::Constants::ACCESS_TOKEN_TYPE,
          client_id: 'broker-issuer',
          audience: 'target-issuer',
          resource: 'https://api.example.gov/passport',
        }
      end

      before do
        form = instance_double(
          OpenidConnectTokenExchangeForm,
          submit: FormResponse.new(success: true, errors: {}),
          response: {
            access_token: 'access-token',
            issued_token_type: TokenExchange::Constants::ACCESS_TOKEN_TYPE,
            token_type: 'Bearer',
            expires_in: 600,
          },
        )
        allow(OpenidConnectTokenExchangeForm).to receive(:new).and_return(form)
      end

      it 'dispatches to the token exchange form' do
        post api_openid_connect_token_path, params: params

        expect(OpenidConnectTokenExchangeForm).to have_received(:new).with(
          hash_including(
            grant_type: TokenExchange::Constants::GRANT_TYPE,
            subject_token: 'subject-token',
            audience: 'target-issuer',
            resource: 'https://api.example.gov/passport',
          ),
        )
      end
    end
  end
end
