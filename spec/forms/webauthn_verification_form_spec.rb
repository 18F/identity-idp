require 'rails_helper'

describe WebauthnVerificationForm do
  include WebAuthnHelper

  let(:user) { create(:user) }
  let(:user_session) { { webauthn_challenge: webauthn_challenge } }
  let(:subject) { WebauthnVerificationForm.new(user, user_session) }
  let(:platform_authenticator) { nil }

  describe '#submit' do
    before do
      create(
        :webauthn_configuration,
        user: user,
        credential_id: credential_id,
        credential_public_key: credential_public_key,
        platform_authenticator: platform_authenticator,
      )
    end

    context 'when the input is valid for non-platform authenticator' do
      it 'returns FormResponse with success: true' do
        allow(IdentityConfig.store).to receive(:domain_name).and_return('localhost:3000')

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

    context 'when the input is valid for platform authenticator' do
      let(:platform_authenticator) { true }

      it 'returns FormResponse with success: true' do
        allow(IdentityConfig.store).to receive(:domain_name).and_return('localhost:3000')

        result = subject.submit(
          protocol,
          authenticator_data: authenticator_data,
          client_data_json: verification_client_data_json,
          signature: signature,
          credential_id: credential_id,
        )

        expect(result.success?).to eq(true)
        expect(result.to_h[:multi_factor_auth_method]).to eq('webauthn_platform')
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

      it 'returns FormResponses with success: false when verification raises OpenSSL exception' do
        allow(IdentityConfig.store).to receive(:domain_name).and_return('localhost:3000')
        allow_any_instance_of(WebAuthn::AuthenticatorAssertionResponse).to receive(:verify).
          and_raise(OpenSSL::PKey::PKeyError)

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
