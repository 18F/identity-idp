require 'rails_helper'

RSpec.describe WebauthnSetupForm do
  include WebAuthnHelper

  let(:user) { create(:user) }
  let(:user_session) { { webauthn_challenge: webauthn_challenge } }
  let(:device_name) { 'Chrome 119 on macOS' }
  let(:domain_name) { 'localhost:3000' }
  let(:attestation) { attestation_object }
  let(:params) do
    {
      attestation_object: attestation,
      client_data_json: setup_client_data_json,
      name: 'mykey',
      platform_authenticator: false,
      transports: 'usb',
      authenticator_data_value: '153',
      protocol:,
    }
  end
  subject(:form) { WebauthnSetupForm.new(user:, user_session:, device_name:) }

  before do
    allow(IdentityConfig.store).to receive(:domain_name).and_return(domain_name)
  end

  describe '#webauthn_configuration' do
    subject(:webauthn_configuration) { form.webauthn_configuration }

    it { is_expected.to be_nil }

    context 'after successful submission' do
      before do
        form.submit(params)
      end

      it 'returns the created configuration' do
        expect(webauthn_configuration).to eq(user.reload.webauthn_configurations.take)
      end
    end
  end

  describe '#submit' do
    subject(:result) { form.submit(params) }

    context 'when the input is valid' do
      context 'security key' do
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
            unknown_transports: nil,
            aaguid: nil,
            pii_like_keypaths: [[:mfa_method_counts, :phone]],
          }

          expect(result.to_h).to eq(
            success: true,
            transports: ['usb'],
            transports_mismatch: false,
            **extra_attributes,
          )

          user.reload

          expect(user.webauthn_configurations.roaming_authenticators.count).to eq(1)
          expect(user.webauthn_configurations.roaming_authenticators.first.transports)
            .to eq(['usb'])
        end

        it 'sends a recovery information changed event' do
          expect(PushNotification::HttpPush).to receive(:deliver)
            .with(PushNotification::RecoveryInformationChangedEvent.new(user: user))

          result
        end

        it 'does not contains uuid' do
          expect(result.extra[:aaguid]).to eq nil
        end
      end

      context 'with platform authenticator' do
        let(:attestation) { platform_auth_attestation_object }
        let(:params) do
          super().merge(platform_authenticator: true, transports: 'internal,hybrid')
        end

        it 'creates a platform authenticator' do
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
            expect(result.to_h[:authenticator_data_flags]).to be_nil
          end
        end

        context 'when authenticator_data_value is missing' do
          let(:params) { super().merge(authenticator_data_value: nil) }

          it 'should not include authenticator data flag' do
            expect(result.to_h[:authenticator_data_flags]).to be_nil
          end
        end

        it 'contains uuid' do
          expect(result.extra[:aaguid]).to eq aaguid
        end
      end

      context 'with invalid transports' do
        let(:params) { super().merge(transports: 'wrong') }

        it 'creates a webauthn configuration without transports' do
          result

          user.reload

          expect(user.webauthn_configurations.roaming_authenticators.first.transports).to be_nil
        end

        it 'includes unknown transports in extra analytics' do
          expect(result.to_h).to eq(
            success: true,
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
            aaguid: nil,
            transports: [],
            transports_mismatch: false,
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
          unknown_transports: nil,
          aaguid: nil,
          pii_like_keypaths: [[:mfa_method_counts, :phone]],
        }

        expect(result.to_h).to eq(
          success: false,
          error_details: { attestation_object: { invalid: true } },
          transports: ['usb'],
          transports_mismatch: false,
          **extra_attributes,
        )
      end
    end

    context 'with missing transports' do
      let(:params) { super().except(:transports) }

      it 'creates a webauthn configuration without transports' do
        result

        user.reload

        expect(user.webauthn_configurations.roaming_authenticators.first.transports).to be_nil
      end
    end

    context 'when the attestation response raises an error' do
      before do
        allow(WebAuthn::AttestationStatement)
          .to receive(:from).and_raise(WebAuthn::AuthenticatorDataFormatError)
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
          unknown_transports: nil,
          aaguid: nil,
          pii_like_keypaths: [[:mfa_method_counts, :phone]],
        }

        expect(result.to_h).to eq(
          success: false,
          error_details: { attestation_object: { invalid: true } },
          transports: ['usb'],
          transports_mismatch: false,
          **extra_attributes,
        )
      end
    end

    context 'with transports mismatch' do
      let(:params) { super().merge(transports: 'internal') }

      it 'returns setup as mismatched type' do
        expect(result.to_h).to eq(
          success: true,
          enabled_mfa_methods_count: 1,
          mfa_method_counts: { webauthn_platform: 1 },
          multi_factor_auth_method: 'webauthn_platform',
          authenticator_data_flags: {
            up: true,
            uv: false,
            be: true,
            bs: true,
            at: false,
            ed: true,
          },
          unknown_transports: nil,
          aaguid: nil,
          transports: ['internal'],
          transports_mismatch: true,
          pii_like_keypaths: [[:mfa_method_counts, :phone]],
        )
      end
    end
  end

  describe '#setup_as_platform_authenticator?' do
    subject(:setup_as_platform_authenticator?) { form.setup_as_platform_authenticator? }

    it { is_expected.to eq(false) }

    context 'after successful submission' do
      before do
        form.submit(params)
      end

      it { is_expected.to eq(false) }

      context 'without transports' do
        let(:params) { super().merge(transports: nil) }

        it { is_expected.to eq(false) }
      end

      context 'with platform authenticator transports' do
        let(:params) { super().merge(transports: 'internal') }

        it { is_expected.to eq(true) }
      end

      context 'when setup as platform authenticator' do
        let(:params) { super().merge(platform_authenticator: true, transports: 'internal') }

        it { is_expected.to eq(true) }

        context 'without transports' do
          let(:params) { super().merge(transports: nil) }

          it { is_expected.to eq(true) }
        end

        context 'without platform authenticator transports' do
          let(:params) { super().merge(transports: 'usb') }

          it { is_expected.to eq(false) }
        end
      end
    end
  end

  describe '#transports_mismatch?' do
    subject(:transports_mismatch?) { form.transports_mismatch? }

    it { is_expected.to eq(false) }

    context 'after successful submission' do
      before do
        form.submit(params)
      end

      it { is_expected.to eq(false) }

      context 'without transports' do
        let(:params) { super().merge(transports: nil) }

        it { is_expected.to eq(false) }
      end

      context 'with platform authenticator transports' do
        let(:params) { super().merge(transports: 'internal') }

        it { is_expected.to eq(true) }
      end

      context 'when setup as platform authenticator' do
        let(:params) { super().merge(platform_authenticator: true, transports: 'internal') }

        it { is_expected.to eq(false) }

        context 'without transports' do
          let(:params) { super().merge(transports: nil) }

          it { is_expected.to eq(false) }
        end

        context 'without platform authenticator transports' do
          let(:params) { super().merge(transports: 'usb') }

          it { is_expected.to eq(true) }
        end
      end
    end
  end

  describe '#event_type' do
    subject(:event_type) { form.event_type }

    before do
      form.submit(params)
    end

    it { is_expected.to eq(:webauthn_key_added) }

    context 'with platform authenticator' do
      let(:attestation) { platform_auth_attestation_object }
      let(:params) do
        super().merge(platform_authenticator: true, transports: 'internal,hybrid')
      end

      it { is_expected.to eq(:webauthn_platform_added) }
    end
  end

  describe '.name_is_unique' do
    context 'webauthn' do
      let(:user) do
        user = create(:user)
        user.webauthn_configurations << create(:webauthn_configuration, name: params[:name])
        user
      end
      it 'checks for unique device on a webauthn device' do
        result = form.submit(params)
        expect(result.extra[:multi_factor_auth_method]).to eq 'webauthn'
        expect(result.errors[:name]).to eq(
          [I18n.t(
            'errors.webauthn_setup.unique_name',
            type: :unique_name,
          )],
        )
        expect(result.to_h[:success]).to eq(false)
      end
    end
    context 'webauthn_platform' do
      let(:params) do
        super().merge(platform_authenticator: true, transports: 'internal,hybrid')
      end

      context 'with one platform authenticator with the same name' do
        let(:user) do
          user = create(:user)
          user.webauthn_configurations << create(
            :webauthn_configuration,
            name: device_name,
            platform_authenticator: true,
            transports: ['internal', 'hybrid'],
          )
          user
        end

        it 'adds a new platform device with the same existing name and appends a (1)' do
          result = form.submit(params)
          expect(result.extra[:multi_factor_auth_method]).to eq 'webauthn_platform'
          expect(user.webauthn_configurations.platform_authenticators.count).to eq(2)
          expect(
            user.webauthn_configurations.platform_authenticators[1].name,
          )
            .to eq("#{device_name} (1)")
          expect(result.to_h[:success]).to eq(true)
        end
      end

      context 'with two existing platform authenticators one with the same name' do
        let!(:user) do
          create(
            :user,
            webauthn_configurations: create_list(
              :webauthn_configuration,
              2,
              name: device_name,
              platform_authenticator: true,
              transports: ['internal', 'hybrid'],
            ),
          )
        end

        it 'adds a second new platform device with the same existing name and appends a (2)' do
          result = form.submit(params)

          expect(result.success?).to eq(true)
          expect(user.webauthn_configurations.platform_authenticators.count).to eq(3)
          expect(user.webauthn_configurations.platform_authenticators.last.name)
            .to eq("#{device_name} (2)")
        end
      end
    end
  end
end
