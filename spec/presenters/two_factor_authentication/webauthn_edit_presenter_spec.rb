require 'rails_helper'

RSpec.describe TwoFactorAuthentication::WebauthnEditPresenter do
  let(:configuration) { build(:webauthn_configuration) }

  subject(:presenter) { described_class.new(configuration:) }

  describe '#heading' do
    subject(:heading) { presenter.heading }

    context 'with roaming authenticator' do
      let(:configuration) { build(:webauthn_configuration) }

      it { expect(heading).to eq(t('two_factor_authentication.webauthn_roaming.edit_heading')) }
    end

    context 'with platform authenticator' do
      let(:configuration) { build(:webauthn_configuration, :platform_authenticator) }

      it { expect(heading).to eq(t('two_factor_authentication.webauthn_platform.edit_heading')) }
    end
  end

  describe '#nickname_field_label' do
    subject(:heading) { presenter.nickname_field_label }

    context 'with roaming authenticator' do
      let(:configuration) { build(:webauthn_configuration) }

      it { expect(heading).to eq(t('two_factor_authentication.webauthn_roaming.nickname')) }
    end

    context 'with platform authenticator' do
      let(:configuration) { build(:webauthn_configuration, :platform_authenticator) }

      it { expect(heading).to eq(t('two_factor_authentication.webauthn_platform.nickname')) }
    end
  end

  describe '#rename_button_label' do
    subject(:heading) { presenter.rename_button_label }

    context 'with roaming authenticator' do
      let(:configuration) { build(:webauthn_configuration) }

      it { expect(heading).to eq(t('two_factor_authentication.webauthn_roaming.change_nickname')) }
    end

    context 'with platform authenticator' do
      let(:configuration) { build(:webauthn_configuration, :platform_authenticator) }

      it { expect(heading).to eq(t('two_factor_authentication.webauthn_platform.change_nickname')) }
    end
  end

  describe '#delete_button_label' do
    subject(:heading) { presenter.delete_button_label }

    context 'with roaming authenticator' do
      let(:configuration) { build(:webauthn_configuration) }

      it { expect(heading).to eq(t('two_factor_authentication.webauthn_roaming.delete')) }
    end

    context 'with platform authenticator' do
      let(:configuration) { build(:webauthn_configuration, :platform_authenticator) }

      it { expect(heading).to eq(t('two_factor_authentication.webauthn_platform.delete')) }
    end
  end

  describe '#rename_success_alert_text' do
    subject(:heading) { presenter.rename_success_alert_text }

    context 'with roaming authenticator' do
      let(:configuration) { build(:webauthn_configuration) }

      it { expect(heading).to eq(t('two_factor_authentication.webauthn_roaming.renamed')) }
    end

    context 'with platform authenticator' do
      let(:configuration) { build(:webauthn_configuration, :platform_authenticator) }

      it { expect(heading).to eq(t('two_factor_authentication.webauthn_platform.renamed')) }
    end
  end

  describe '#delete_success_alert_text' do
    subject(:heading) { presenter.delete_success_alert_text }

    context 'with roaming authenticator' do
      let(:configuration) { build(:webauthn_configuration) }

      it { expect(heading).to eq(t('two_factor_authentication.webauthn_roaming.deleted')) }
    end

    context 'with platform authenticator' do
      let(:configuration) { build(:webauthn_configuration, :platform_authenticator) }

      it { expect(heading).to eq(t('two_factor_authentication.webauthn_platform.deleted')) }
    end
  end
end
