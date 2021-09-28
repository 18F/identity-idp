require 'rails_helper'

describe WebauthnSetupForm do
  include WebAuthnHelper

  let(:user) { create(:user) }
  let(:user_session) { { webauthn_challenge: webauthn_challenge } }
  let(:subject) { WebauthnSetupForm.new(user, user_session) }

  describe '#submit' do
    context 'when the input is valid' do
      it 'returns FormResponse with success: true' do
        allow(IdentityConfig.store).to receive(:domain_name).and_return('localhost:3000')
        params = {
          attestation_object: attestation_object,
          client_data_json: setup_client_data_json,
          name: 'mykey',
        }
        extra_attributes = {
          mfa_method_counts: { webauthn: 1 },
          multi_factor_auth_method: 'webauthn',
          pii_like_keypaths: [[:mfa_method_counts, :phone]],
        }

        expect(subject.submit(protocol, params).to_h).to eq(
          success: true,
          errors: {},
          **extra_attributes,
        )
      end

      it 'sends a recovery information changed event' do
        allow(IdentityConfig.store).to receive(:domain_name).and_return('localhost:3000')
        expect(PushNotification::HttpPush).to receive(:deliver).
          with(PushNotification::RecoveryInformationChangedEvent.new(user: user))

        params = {
          attestation_object: attestation_object,
          client_data_json: setup_client_data_json,
          name: 'mykey',
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
        }
        extra_attributes = {
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
        }
        extra_attributes = {
          mfa_method_counts: {},
          multi_factor_auth_method: 'webauthn',
          pii_like_keypaths: [[:mfa_method_counts, :phone]],
        }

        expect(subject.submit(protocol, params).to_h).to eq(
          success: false,
          errors: { name: [I18n.t('errors.webauthn_setup.attestation_error')] },
          error_details: { name: [I18n.t('errors.webauthn_setup.attestation_error')] },
          **extra_attributes,
        )
      end
    end
  end
end
