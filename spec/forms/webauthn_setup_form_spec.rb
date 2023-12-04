require 'rails_helper'

RSpec.describe WebauthnSetupForm do
  include WebAuthnHelper

  let(:user) { create(:user) }
  let(:user_session) { { webauthn_challenge: webauthn_challenge } }
  let(:device_name) { 'Chrome 119 on macOS 10' }
  let(:domain_name) { 'localhost:3000' }
  let(:params) do
    {
      attestation_object: attestation_object,
      client_data_json: setup_client_data_json,
      name: 'mykey',
      platform_authenticator: false,
      transports: 'usb',
      authenticator_data_value: '153',
    }
  end
  let(:subject) { WebauthnSetupForm.new(user:, user_session:, device_name:) }

  before do
    allow(IdentityConfig.store).to receive(:domain_name).and_return(domain_name)
  end

  describe '#submit' do
    context 'when the input is valid' do
      it 'returns FormResponse with success: true and creates a webauthn configuration' do
        extra_attributes = {
          enabled_mfa_methods_count: 1,
          mfa_method_counts: { webauthn: 1 },
          multi_factor_auth_method: 'webauthn',
          authenticator_data_flags: {
            up: true,
            uv: false,
            be: true,
            bs: true,
            at: false,
            ed: true,
          },
          pii_like_keypaths: [[:mfa_method_counts, :phone]],
        }

        expect(subject.submit(protocol, params).to_h).to eq(
          success: true,
          errors: {},
          **extra_attributes,
        )

        user.reload

        expect(user.webauthn_configurations.roaming_authenticators.count).to eq(1)
        expect(user.webauthn_configurations.roaming_authenticators.first.transports).to eq(['usb'])
      end

      it 'sends a recovery information changed event' do
        expect(PushNotification::HttpPush).to receive(:deliver).
          with(PushNotification::RecoveryInformationChangedEvent.new(user: user))

        subject.submit(protocol, params)
      end

      context 'with platform authenticator' do
        let(:params) do
          super().merge(platform_authenticator: true, transports: 'internal,hybrid')
        end

        it 'creates a platform authenticator' do
          result = subject.submit(protocol, params)
          expect(result.extra[:multi_factor_auth_method]).to eq 'webauthn_platform'

          user.reload

          expect(user.webauthn_configurations.platform_authenticators.count).to eq(1)
          expect(user.webauthn_configurations.platform_authenticators.first.transports).to eq(
            ['internal', 'hybrid'],
          )
        end

        context 'with non backed up option data flags' do
          let(:params) { super().merge(authenticator_data_value: '65') }

          it 'includes data flags with bs set as false ' do
            result = subject.submit(protocol, params)

            expect(result.to_h[:authenticator_data_flags]).to eq(
              up: true,
              uv: false,
              be: false,
              bs: false,
              at: true,
              ed: false,
            )
          end
        end

        context 'when authenticator_data_value is not a number' do
          let(:params) { super().merge(authenticator_data_value: 'bad_error') }

          it 'should not include authenticator data flag' do
            result = subject.submit(protocol, params)

            expect(result.to_h[:authenticator_data_flags]).to be_nil
          end
        end

        context 'when authenticator_data_value is missing' do
          let(:params) { super().merge(authenticator_data_value: nil) }

          it 'should not include authenticator data flag' do
            result = subject.submit(protocol, params)

            expect(result.to_h[:authenticator_data_flags]).to be_nil
          end
        end
      end

      context 'with invalid transports' do
        let(:params) { super().merge(transports: 'wrong') }

        it 'creates a webauthn configuration without transports' do
          subject.submit(protocol, params)

          user.reload

          expect(user.webauthn_configurations.roaming_authenticators.first.transports).to be_nil
        end

        it 'includes unknown transports in extra analytics' do
          result = subject.submit(protocol, params)

          expect(result.to_h).to eq(
            success: true,
            errors: {},
            enabled_mfa_methods_count: 1,
            mfa_method_counts: { webauthn: 1 },
            multi_factor_auth_method: 'webauthn',
            authenticator_data_flags: {
              up: true,
              uv: false,
              be: true,
              bs: true,
              at: false,
              ed: true,
            },
            pii_like_keypaths: [[:mfa_method_counts, :phone]],
            unknown_transports: ['wrong'],
          )
        end
      end
    end

    context 'with invalid attestation response from domain' do
      let(:domain_name) { 'example.com' }

      it 'returns FormResponse with success: false' do
        extra_attributes = {
          enabled_mfa_methods_count: 0,
          mfa_method_counts: {},
          multi_factor_auth_method: 'webauthn',
          authenticator_data_flags: {
            up: true,
            uv: false,
            be: true,
            bs: true,
            at: false,
            ed: true,
          },
          pii_like_keypaths: [[:mfa_method_counts, :phone]],
        }

        expect(subject.submit(protocol, params).to_h).to eq(
          success: false,
          errors: {},
          **extra_attributes,
        )
      end
    end

    context 'with missing transports' do
      let(:params) { super().except(:transports) }

      it 'creates a webauthn configuration without transports' do
        subject.submit(protocol, params)

        user.reload

        expect(user.webauthn_configurations.roaming_authenticators.first.transports).to be_nil
      end
    end

    context 'when the attestation response raises an error' do
      before do
        allow(WebAuthn::AttestationStatement).to receive(:from).and_raise(StandardError)
      end

      it 'returns false with an error when the attestation response raises an error' do
        extra_attributes = {
          enabled_mfa_methods_count: 0,
          mfa_method_counts: {},
          multi_factor_auth_method: 'webauthn',
          authenticator_data_flags: {
            up: true,
            uv: false,
            be: true,
            bs: true,
            at: false,
            ed: true,
          },
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
