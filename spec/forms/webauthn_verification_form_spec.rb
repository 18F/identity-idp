require 'rails_helper'

describe WebauthnVerificationForm do
  include WebAuthnHelper

  let(:user) { create(:user) }
  let(:challenge) { webauthn_challenge }
  let(:webauthn_error) { nil }
  let(:platform_authenticator) { false }

  subject(:form) do
    WebauthnVerificationForm.new(
      user: user,
      challenge: challenge,
      protocol: protocol,
      authenticator_data: authenticator_data,
      client_data_json: verification_client_data_json,
      signature: signature,
      credential_id: credential_id,
      webauthn_error: webauthn_error,
    )
  end

  describe '#submit' do
    before do
      create(
        :webauthn_configuration,
        user: user,
        credential_id: credential_id,
        credential_public_key: credential_public_key,
        platform_authenticator: platform_authenticator,
      )

      allow(IdentityConfig.store).to receive(:domain_name).and_return('localhost:3000')
    end

    subject(:result) { form.submit }

    context 'when the input is valid' do
      it 'returns FormResponse with success: true' do
        expect(result.success?).to eq(true)
        expect(result.to_h[:multi_factor_auth_method]).to eq('webauthn')
      end

      context 'for platform authenticator' do
        let(:platform_authenticator) { true }

        it 'returns FormResponse with success: true' do
          expect(result.success?).to eq(true)
          expect(result.to_h[:multi_factor_auth_method]).to eq('webauthn_platform')
        end
      end
    end

    context 'when the input is invalid' do
      context 'when origin is invalid' do
        before do
          allow(IdentityConfig.store).to receive(:domain_name).and_return('localhost:6666')
        end

        it 'returns FormResponse with success: false' do
          expect(result.success?).to eq(false)
          expect(result.to_h[:multi_factor_auth_method]).to eq('webauthn')
        end
      end

      context 'when verification raises OpenSSL exception' do
        before do
          allow_any_instance_of(WebAuthn::AuthenticatorAssertionResponse).to receive(:verify).
            and_raise(OpenSSL::PKey::PKeyError)
        end

        it 'returns FormResponses with success: false' do
          expect(result.success?).to eq(false)
          expect(result.to_h[:multi_factor_auth_method]).to eq('webauthn')
        end
      end
    end
  end
end
