require 'rails_helper'

RSpec.describe WebauthnSetupMismatchPresenter do
  subject(:presenter) { described_class.new(configuration:) }
  let(:platform_authenticator) {}
  let(:configuration) { create(:webauthn_configuration, platform_authenticator:) }

  describe '#heading' do
    subject(:heading) { presenter.heading }

    context 'with non-platform authenticator' do
      let(:platform_authenticator) { false }

      it { is_expected.to eq(t('webauthn_setup_mismatch.heading.webauthn')) }
    end

    context 'with platform authenticator' do
      let(:platform_authenticator) { true }

      it { is_expected.to eq(t('webauthn_setup_mismatch.heading.webauthn_platform')) }
    end
  end

  describe '#description' do
    subject(:description) { presenter.description }

    context 'with non-platform authenticator' do
      let(:platform_authenticator) { false }

      it { is_expected.to eq(t('webauthn_setup_mismatch.description.webauthn_html')) }
    end

    context 'with platform authenticator' do
      let(:platform_authenticator) { true }

      it { is_expected.to eq(t('webauthn_setup_mismatch.description.webauthn_platform_html')) }
    end
  end

  describe '#correct_image_path' do
    subject(:correct_image_path) { presenter.correct_image_path }

    context 'with non-platform authenticator' do
      let(:platform_authenticator) { false }

      it { is_expected.to eq('webauthn-mismatch/webauthn-checked.svg') }
    end

    context 'with platform authenticator' do
      let(:platform_authenticator) { true }

      it { is_expected.to eq('webauthn-mismatch/webauthn-platform-checked.svg') }
    end
  end

  describe '#incorrect_image_path' do
    subject(:incorrect_image_path) { presenter.incorrect_image_path }

    context 'with non-platform authenticator' do
      let(:platform_authenticator) { false }

      it { is_expected.to eq('webauthn-mismatch/webauthn-platform-unchecked.svg') }
    end

    context 'with platform authenticator' do
      let(:platform_authenticator) { true }

      it { is_expected.to eq('webauthn-mismatch/webauthn-unchecked.svg') }
    end
  end
end
