require 'rails_helper'

describe WebauthnSetupForm do
  include WebAuthnHelper

  let(:user) { create(:user) }
  let(:user_session) { { webauthn_challenge: webauthn_challenge } }
  let(:subject) { WebauthnSetupForm.new(user, user_session) }

  describe '#submit' do
    context 'when the input is valid' do
      it 'returns FormResponse with success: true and creates a webauthn configuration' do
        allow(IdentityConfig.store).to receive(:domain_name).and_return('localhost:3000')
        params = {
          attestation_object: attestation_object,
          client_data_json: setup_client_data_json,
          name: 'mykey',
          platform_authenticator: false,
        }
        extra_attributes = {
          enabled_mfa_methods_count: 1,
          mfa_method_counts: { webauthn: 1 },
          multi_factor_auth_method: 'webauthn',
          pii_like_keypaths: [[:mfa_method_counts, :phone]],
        }

        expect(subject.submit(protocol, params).to_h).to eq(
          success: true,
          errors: {},
          **extra_attributes,
        )

        expect(user.reload.webauthn_configurations.roaming_authenticators.count).to eq(1)
      end

      it 'creates a platform authenticator if the platform_authenticator param is set' do
        allow(IdentityConfig.store).to receive(:domain_name).and_return('localhost:3000')
        params = {
          attestation_object: attestation_object,
          client_data_json: setup_client_data_json,
          name: 'mykey',
          platform_authenticator: true,
        }

        result = subject.submit(protocol, params)
        expect(result.extra[:multi_factor_auth_method]).to eq 'webauthn_platform'

        expect(user.reload.webauthn_configurations.platform_authenticators.count).to eq(1)
      end

      it 'sends a recovery information changed event' do
        allow(IdentityConfig.store).to receive(:domain_name).and_return('localhost:3000')
        expect(PushNotification::HttpPush).to receive(:deliver).
          with(PushNotification::RecoveryInformationChangedEvent.new(user: user))

        params = {
          attestation_object: attestation_object,
          client_data_json: setup_client_data_json,
          name: 'mykey',
          platform_authenticator: false,
        }

        subject.submit(protocol, params)
      end
    end

    context 'when the input is invalid' do
      it 'returns FormResponse with success: false' do
        params = {
          attestation_object: attestation_object,
          client_data_json: setup_client_data_json,
          name: 'mykey',
          platform_authenticator: false,
        }
        extra_attributes = {
          enabled_mfa_methods_count: 0,
          mfa_method_counts: {},
          multi_factor_auth_method: 'webauthn',
          pii_like_keypaths: [[:mfa_method_counts, :phone]],
        }

        expect(subject.submit(protocol, params).to_h).to eq(
          success: false,
          errors: {},
          **extra_attributes,
        )
      end

      it 'returns false with an error when the attestation response raises an error' do
        allow(IdentityConfig.store).to receive(:domain_name).and_return('localhost:3000')
        allow(WebAuthn::AttestationStatement).to receive(:from).and_raise(StandardError)

        params = {
          attestation_object: attestation_object,
          client_data_json: setup_client_data_json,
          name: 'mykey',
          platform_authenticator: false,
        }
        extra_attributes = {
          enabled_mfa_methods_count: 0,
          mfa_method_counts: {},
          multi_factor_auth_method: 'webauthn',
          pii_like_keypaths: [[:mfa_method_counts, :phone]],
        }

        expect(subject.submit(protocol, params).to_h).to eq(
          success: false,
          errors: { name: [I18n.t(
            'errors.webauthn_setup.attestation_error',
            link: MarketingSite.contact_url,
          )] },
          error_details: { name: { attestation_error: true } },
          **extra_attributes,
        )
      end
    end
  end
end
