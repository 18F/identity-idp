require 'rails_helper'

RSpec.describe WebauthnSetupPresenter do
  include Rails.application.routes.url_helpers
  include ActionView::Helpers::UrlHelper

  let(:user) { build(:user) }
  let(:user_fully_authenticated) { false }
  let(:user_opted_remember_device_cookie) { true }
  let(:remember_device_default) { true }
  let(:platform_authenticator) { false }
  let(:presenter) do
    described_class.new(
      current_user: user,
      user_fully_authenticated: user_fully_authenticated,
      user_opted_remember_device_cookie: user_opted_remember_device_cookie,
      remember_device_default: remember_device_default,
      platform_authenticator: platform_authenticator,
      url_options: {},
    )
  end

  describe '#image_path' do
    subject { presenter.image_path }

    it { is_expected.to eq('security-key.svg') }
  end

  describe '#page_title' do
    subject { presenter.page_title }

    it { is_expected.to eq(t('titles.webauthn_setup')) }
  end

  describe '#heading' do
    subject { presenter.heading }

    it { is_expected.to eq(t('headings.webauthn_setup.new')) }
  end

  describe '#intro_html' do
    subject { presenter.intro_html }

    it { is_expected.to eq(t('forms.webauthn_setup.intro_html')) }
  end

  describe '#nickname_label' do
    subject { presenter.nickname_label }

    it { is_expected.to eq(t('forms.webauthn_setup.nickname')) }
  end

  describe '#device_nickname_hint' do
    subject { presenter.device_nickname_hint }

    it { is_expected.to eq(nil) }
  end

  describe '#button_text' do
    subject { presenter.button_text }

    it { is_expected.to eq(t('forms.webauthn_setup.continue')) }
  end

  context 'with platform_authenticator' do
    let(:platform_authenticator) { true }

    describe '#image_path' do
      subject { presenter.image_path }

      it { is_expected.to eq('platform-authenticator.svg') }
    end

    describe '#page_title' do
      subject { presenter.page_title }

      it { is_expected.to eq(t('headings.webauthn_platform_setup.new')) }
    end

    describe '#heading' do
      subject { presenter.heading }

      it { is_expected.to eq(t('headings.webauthn_platform_setup.new')) }
    end

    describe '#intro_html' do
      subject { presenter.intro_html }

      it do
        is_expected.to eq(
          t(
            'forms.webauthn_platform_setup.intro_html',
            app_name: APP_NAME,
            link: link_to(
              t('forms.webauthn_platform_setup.intro_link_text'),
              help_center_redirect_path(
                category: 'trouble-signing-in',
                article: 'face-or-touch-unlock',
                flow: :two_factor_authentication,
                step: :webauthn_setup,
              ),
            ),
          ),
        )
      end
    end

    describe '#nickname_label' do
      subject { presenter.nickname_label }

      it { is_expected.to eq(t('forms.webauthn_platform_setup.nickname')) }
    end

    describe '#device_nickname_hint' do
      subject { presenter.device_nickname_hint }

      it { is_expected.to eq(t('forms.webauthn_platform_setup.nickname_hint')) }
    end

    describe '#button_text' do
      subject { presenter.button_text }

      it { is_expected.to eq(t('forms.webauthn_platform_setup.continue')) }
    end
  end
end
