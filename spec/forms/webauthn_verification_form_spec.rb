require 'rails_helper'

RSpec.describe WebauthnVerificationForm do
  include WebAuthnHelper

  let(:user) { create(:user) }
  let(:challenge) { webauthn_challenge }
  let(:webauthn_error) { nil }
  let(:platform_authenticator) { false }
  let(:client_data_json) { verification_client_data_json }
  let!(:webauthn_configuration) do
    return if !user
    create(
      :webauthn_configuration,
      user:,
      credential_id:,
      credential_public_key:,
      platform_authenticator:,
    )
  end

  subject(:form) do
    WebauthnVerificationForm.new(
      user:,
      challenge:,
      protocol:,
      authenticator_data:,
      client_data_json:,
      signature:,
      credential_id:,
      webauthn_error:,
    )
  end

  describe '#submit' do
    before do
      allow(IdentityConfig.store).to receive(:domain_name).and_return('localhost:3000')
    end

    subject(:result) { form.submit }

    context 'when the input is valid' do
      it 'returns successful result' do
        expect(result.to_h).to eq(
          success: true,
          multi_factor_auth_method: 'webauthn',
          webauthn_configuration_id: webauthn_configuration.id,
        )
      end

      context 'for platform authenticator' do
        let(:platform_authenticator) { true }

        it 'returns successful result' do
          expect(result.to_h).to eq(
            success: true,
            multi_factor_auth_method: 'webauthn_platform',
            webauthn_configuration_id: webauthn_configuration.id,
          )
        end
      end
    end

    context 'when the input is invalid' do
      context 'when user is missing' do
        let(:user) { nil }

        it 'returns unsuccessful result' do
          expect(result.to_h).to eq(
            success: false,
            error_details: { user: [:blank], webauthn_configuration: [:blank] },
            multi_factor_auth_method: 'webauthn',
            webauthn_configuration_id: nil,
          )
        end
      end

      context 'when challenge is missing' do
        let(:challenge) { nil }

        it 'returns unsuccessful result' do
          expect(result.to_h).to eq(
            success: false,
            error_details: {
              challenge: [:blank],
              authenticator_data: ['invalid_authenticator_data'],
            },
            multi_factor_auth_method: 'webauthn',
            webauthn_configuration_id: webauthn_configuration.id,
          )
        end
      end

      context 'when authenticator data is missing' do
        let(:authenticator_data) { nil }

        it 'returns unsuccessful result' do
          expect(result.to_h).to eq(
            success: false,
            error_details: {
              authenticator_data: [:blank, 'invalid_authenticator_data'],
            },
            multi_factor_auth_method: 'webauthn',
            webauthn_configuration_id: webauthn_configuration.id,
          )
        end
      end

      context 'when client_data_json is missing' do
        let(:client_data_json) { nil }

        it 'returns unsuccessful result' do
          expect(result.to_h).to eq(
            success: false,
            error_details: {
              client_data_json: [:blank],
              authenticator_data: ['invalid_authenticator_data'],
            },
            multi_factor_auth_method: 'webauthn',
            webauthn_configuration_id: webauthn_configuration.id,
          )
        end
      end

      context 'when signature is missing' do
        let(:signature) { nil }

        it 'returns unsuccessful result' do
          expect(result.to_h).to eq(
            success: false,
            error_details: {
              signature: [:blank],
              authenticator_data: ['invalid_authenticator_data'],
            },
            multi_factor_auth_method: 'webauthn',
            webauthn_configuration_id: webauthn_configuration.id,
          )
        end
      end

      context 'when user has no configured webauthn' do
        let(:webauthn_configuration) { nil }

        it 'returns unsuccessful result' do
          expect(result.to_h).to eq(
            success: false,
            error_details: { webauthn_configuration: [:blank] },
            multi_factor_auth_method: 'webauthn',
            webauthn_configuration_id: nil,
          )
        end
      end

      context 'when a client-side webauthn error is present' do
        let(:webauthn_error) { 'Unexpected error!' }

        it 'returns unsuccessful result including client-side webauthn error text' do
          expect(result.to_h).to eq(
            success: false,
            error_details: { webauthn_error: [webauthn_error] },
            multi_factor_auth_method: 'webauthn',
            webauthn_configuration_id: webauthn_configuration.id,
          )
        end
      end

      context 'when origin is invalid' do
        before do
          allow(IdentityConfig.store).to receive(:domain_name).and_return('localhost:6666')
        end

        it 'returns unsuccessful result' do
          expect(result.to_h).to eq(
            success: false,
            error_details: { authenticator_data: ['invalid_authenticator_data'] },
            multi_factor_auth_method: 'webauthn',
            webauthn_configuration_id: webauthn_configuration.id,
          )
        end
      end

      context 'when verification raises OpenSSL exception' do
        before do
          allow_any_instance_of(WebAuthn::AuthenticatorAssertionResponse).to receive(:verify).
            and_raise(OpenSSL::PKey::PKeyError)
        end

        it 'returns unsucessful result' do
          expect(result.to_h).to eq(
            success: false,
            error_details: { authenticator_data: ['invalid_authenticator_data'] },
            multi_factor_auth_method: 'webauthn',
            webauthn_configuration_id: webauthn_configuration.id,
          )
        end
      end
    end
  end
end
