require 'rails_helper'

RSpec.describe 'two_factor_authentication/webauthn_verification/show.html.erb' do
  let(:user) { build_stubbed(:user) }
  let(:platform_authenticator) { false }
  let(:auto_prompt) { false }

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
      auto_prompt:,
    )
  end

  it 'includes a page title for webauthn authenticator' do
    expect(view).to receive(:title=).with(t('titles.present_webauthn'))

    render
  end

  it 'includes hidden platform form input with value false' do
    expect(rendered).to have_field('platform', with: 'false', type: 'hidden')
  end

  it 'allows the user to choose another authentication method' do
    expect(rendered).to have_link(
      t('two_factor_authentication.login_options_link_text'),
      href: login_two_factor_options_path,
    )
  end

  it 'does not provide a cancel link' do
    expect(rendered).not_to have_link(t('links.cancel'))
  end

  context 'when auto prompt is enabled' do
    let(:auto_prompt) { true }

    it 'adds the auto prompt dataset to the webauthn button element' do
      expect(rendered).to have_css('lg-webauthn-verify-button[data-auto-prompt="true"]')
    end
  end

  context 'with platform authenticator' do
    let(:platform_authenticator) { true }

    it 'includes a page title for a platform authenticator' do
      expect(view).to receive(:title=).with(
        t('two_factor_authentication.webauthn_platform_header_text'),
      )

      render
    end

    it 'includes hidden platform form input with value true' do
      expect(rendered).to have_field('platform', with: 'true', type: 'hidden')
    end
  end
end
