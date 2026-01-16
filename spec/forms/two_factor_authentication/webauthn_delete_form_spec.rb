require 'rails_helper'

RSpec.describe TwoFactorAuthentication::WebauthnDeleteForm do
  let(:user) { create(:user) }
  let(:configuration) { create(:webauthn_configuration, user:) }
  let(:configuration_id) { configuration&.id }
  let(:skip_multiple_mfa_validation) {}
  let(:form) do
    described_class.new(user:, configuration_id:, **{ skip_multiple_mfa_validation: }.compact)
  end

  describe '#submit' do
    let(:result) { form.submit }

    context 'with having another mfa enabled' do
      let(:user) { create(:user, :with_phone) }

      it 'returns a successful result' do
        expect(result.success?).to eq(true)
        expect(result.to_h).to eq(
          success: true,
          configuration_id:,
          platform_authenticator: false,
        )
      end

      context 'with platform authenticator' do
        let(:configuration) do
          create(:webauthn_configuration, :platform_authenticator, user:)

          it 'includes platform authenticator detail in result' do
            expect(result.to_h[:platform_authenticator]).to eq(true)
          end
        end
      end

      context 'with blank configuration' do
        let(:configuration) { nil }

        it 'returns an unsuccessful result' do
          expect(result.success?).to eq(false)
          expect(result.to_h).to eq(
            success: false,
            error_details: {
              configuration_id: { configuration_not_found: true },
            },
            configuration_id:,
            platform_authenticator: nil,
          )
        end
      end

      context 'with configuration that does not exist' do
        let(:configuration_id) { 'does-not-exist' }

        it 'returns an unsuccessful result' do
          expect(result.success?).to eq(false)
          expect(result.to_h).to eq(
            success: false,
            error_details: {
              configuration_id: { configuration_not_found: true },
            },
            configuration_id:,
            platform_authenticator: nil,
          )
        end
      end

      context 'with configuration not belonging to the user' do
        let(:configuration) { create(:webauthn_configuration) }

        it 'returns an unsuccessful result' do
          expect(result.success?).to eq(false)
          expect(result.to_h).to eq(
            success: false,
            error_details: {
              configuration_id: { configuration_not_found: true },
            },
            configuration_id:,
            platform_authenticator: nil,
          )
        end
      end
    end

    context 'with user not having another mfa enabled' do
      let(:user) { create(:user) }

      it 'returns an unsuccessful result' do
        expect(result.success?).to eq(false)
        expect(result.to_h).to eq(
          success: false,
          error_details: {
            configuration_id: { only_method: true },
          },
          configuration_id:,
          platform_authenticator: false,
        )
      end

      context 'with skipped multiple mfa validation' do
        let(:skip_multiple_mfa_validation) { true }

        it 'returns a successful result' do
          expect(result.success?).to eq(true)
          expect(result.to_h).to eq(
            success: true,
            configuration_id:,
            platform_authenticator: false,
          )
        end
      end

      context 'with platform authenticator' do
        let(:configuration) do
          create(:webauthn_configuration, :platform_authenticator, user:)

          it 'includes platform authenticator detail in result' do
            expect(result.to_h[:platform_authenticator]).to eq(true)
          end
        end
      end
    end
  end

  describe '#configuration' do
    subject(:form_configuration) { form.configuration }

    it 'returns configuration' do
      expect(form_configuration).to eq(configuration)
    end
  end

  describe '#platform_authenticator?' do
    subject(:platform_authenticator?) { form.platform_authenticator? }

    context 'without configuration' do
      let(:configuration) { nil }

      it { is_expected.to be_nil }
    end

    context 'with configuration' do
      let(:configuration) { create(:webauthn_configuration, user:) }

      it 'delegates to configuration' do
        expect(platform_authenticator?).to eq(configuration.platform_authenticator?)
      end
    end
  end

  describe '#event_type' do
    subject(:event_type) { form.event_type }

    context 'with security key' do
      let(:configuration) { create(:webauthn_configuration, user:) }

      it { is_expected.to eq(:webauthn_key_removed) }
    end

    context 'with platform authenticator' do
      let(:configuration) { create(:webauthn_configuration, :platform_authenticator, user:) }

      it { is_expected.to eq(:webauthn_platform_removed) }
    end
  end
end
