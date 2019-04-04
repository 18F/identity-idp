require 'rails_helper'

describe WebauthnVerificationForm do
  include WebAuthnHelper

  let(:user) { create(:user) }
  let(:user_session) { { webauthn_challenge: webauthn_challenge } }
  let(:subject) { WebauthnVerificationForm.new(user, user_session) }

  describe '#submit' do
    before do
      create(
        :webauthn_configuration,
        user: user,
        credential_id: credential_id,
        credential_public_key: credential_public_key,
      )
    end

    context 'when the input is valid' do
      it 'returns FormResponse with success: true' do
        allow(Figaro.env).to receive(:domain_name).and_return('localhost:3000')

        result = subject.submit(
          protocol,
          authenticator_data: authenticator_data,
          client_data_json: verification_client_data_json,
          signature: signature,
          credential_id: credential_id,
        )

        expect(result.success?).to eq(true)
        expect(result.to_h[:multi_factor_auth_method]).to eq('webauthn')
      end
    end

    context 'when the input is invalid' do
      it 'returns FormResponse with success: false' do
        result = subject.submit(
          protocol,
          authenticator_data: authenticator_data,
          client_data_json: verification_client_data_json,
          signature: signature,
          credential_id: credential_id,
        )

        expect(result.success?).to eq(false)
        expect(result.to_h[:multi_factor_auth_method]).to eq('webauthn')
      end
    end
  end
end
