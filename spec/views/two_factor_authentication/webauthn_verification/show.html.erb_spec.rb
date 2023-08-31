require 'rails_helper'

RSpec.describe 'two_factor_authentication/webauthn_verification/show.html.erb' do
  let(:user) { build_stubbed(:user) }
  let(:platform_authenticator) { false }
  let(:phishing_resistant_required) { false }
  let(:service_provider_mfa_policy) do
    ServiceProviderMfaPolicy.new(
      user:,
      service_provider: nil,
      auth_method: :webauthn,
      aal_level_requested: nil,
      piv_cac_requested: false,
      phishing_resistant_requested: phishing_resistant_required,
    )
  end

  subject(:rendered) { render }

  before do
    allow(view).to receive(:current_user).and_return(user)
    allow(view).to receive(:user_session).and_return({})
    allow(view).to receive(:sp_session).and_return({})
    @presenter = TwoFactorAuthCode::WebauthnAuthenticationPresenter.new(
      view:,
      data: {},
      service_provider: nil,
      platform_authenticator:,
    )
    allow(@presenter).to receive(
      :service_provider_mfa_policy,
    ).and_return(service_provider_mfa_policy)
  end

  it 'includes hidden platform form input with value false' do
    expect(rendered).to have_field('platform', with: 'false', type: 'hidden')
  end

  it 'includes troubleshooting link to use another authentication method' do
    expect(rendered).to have_css('.troubleshooting-options li', count: 2)
    expect(rendered).to have_link(
      t('two_factor_authentication.login_options_link_text'),
      href: login_two_factor_options_path,
    )
  end

  context 'with platform authenticator' do
    let(:platform_authenticator) { true }

    it 'includes hidden platform form input with value false' do
      expect(rendered).to have_field('platform', with: 'true', type: 'hidden')
    end

    it 'includes troubleshooting link to learn more about face/touch unlock' do
      expect(rendered).to have_css('.troubleshooting-options li', count: 3)
      expect(rendered).to have_link(
        t('instructions.mfa.webauthn_platform.learn_more_help'),
        href: help_center_redirect_path(
          category: 'trouble-signing-in',
          article: 'face-or-touch-unlock',
          flow: :two_factor_authentication,
          step: :webauthn_verification,
        ),
      )
    end
  end

  context 'with phishing-resistant MFA requirement' do
    let(:phishing_resistant_required) { true }

    it 'does not include a troubleshooting link for using another MFA method' do
      expect(rendered).to have_css('.troubleshooting-options li', count: 1)
    end

    context 'with user having PIV/CAC configured' do
      let(:user) { build(:user, :with_piv_or_cac, :with_webauthn) }

      it 'includes troubleshooting link to use PIV/CAC' do
        expect(rendered).to have_css('.troubleshooting-options li', count: 2)
        expect(rendered).to have_link(
          t('two_factor_authentication.webauthn_piv_available'),
          href: login_two_factor_piv_cac_url,
        )
      end
    end
  end
end
