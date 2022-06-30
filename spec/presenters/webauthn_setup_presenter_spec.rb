require 'rails_helper'

describe WebauthnSetupPresenter do
  let(:user) { build(:user) }
  let(:user_fully_authenticated) { false }
  let(:user_opted_remember_device_cookie) { true }
  let(:remember_device_default) { true }
  let(:platform_authenticator) { false }
  let(:intro_link) do
    MarketingSite.help_center_article_url(
      category: 'get-started',
      article: 'authentication-options',
    )
  end
  let(:presenter) do
    described_class.new(
      current_user: user,
      user_fully_authenticated: user_fully_authenticated,
      user_opted_remember_device_cookie: user_opted_remember_device_cookie,
      remember_device_default: remember_device_default,
      platform_authenticator: platform_authenticator,
    )
  end

  describe '#image_path' do
    subject { presenter.image_path }

    it { is_expected.to  eq('security-key.svg') }
  end

  describe '#heading' do
    subject { presenter.heading }

    it { is_expected.to  eq(t('headings.webauthn_setup.new')) }
  end

  describe '#intro_html' do
    subject { presenter.intro_html }

    it { is_expected.to eq(t('forms.webauthn_setup.intro_html')) }
  end

  describe '#intro_link' do
    subject { presenter.intro_link }

    it { is_expected.to include(t('forms.webauthn_platform_setup.intro_link_text')) }
    it { is_expected.to include(intro_link) }
  end

  describe '#nickname_label' do
    subject { presenter.nickname_label }

    it { is_expected.to eq(t('forms.webauthn_setup.nickname')) }
  end

  describe '#button_text' do
    subject { presenter.button_text }

    it { is_expected.to  eq(t('forms.webauthn_setup.continue')) }
  end

  describe '#setup_heading' do
    subject { presenter.setup_heading }

    it { is_expected.to  eq(t('forms.webauthn_setup.instructions_title')) }
  end

  context 'with platform_authenticator' do
    let(:platform_authenticator) { true }

    describe '#image_path' do
      subject { presenter.image_path }

      it { is_expected.to  eq('platform-authenticator.svg') }
    end

    describe '#heading' do
      subject { presenter.heading }

      it { is_expected.to  eq(t('headings.webauthn_platform_setup.new')) }
    end

    describe '#nickname_label' do
      subject { presenter.nickname_label }

      it { is_expected.to eq(t('forms.webauthn_platform_setup.nickname')) }
    end

    describe '#button_text' do
      subject { presenter.button_text }

      it { is_expected.to  eq(t('forms.webauthn_platform_setup.continue')) }
    end

    describe '#setup_heading' do
      subject { presenter.setup_heading }

      it { is_expected.to  eq(t('forms.webauthn_platform_setup.instructions_title')) }
    end
  end
end
