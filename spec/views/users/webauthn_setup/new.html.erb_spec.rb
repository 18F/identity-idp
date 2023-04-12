require 'rails_helper'

describe 'users/webauthn_setup/new.html.erb' do
  let(:user) { create(:user, :signed_up) }

  context 'webauthn platform' do
    let(:platform_authenticator) { true }
    let(:user_session) do
      { webauthn_challenge: 'fake_challenge' }
    end
    let(:presenter) do
      WebauthnSetupPresenter.new(
        current_user: user,
        user_fully_authenticated: true,
        user_opted_remember_device_cookie: true,
        remember_device_default: true,
        platform_authenticator: platform_authenticator,
      )
    end

    before do
      allow(view).to receive(:current_user).and_return(user)
      allow(view).to receive(:user_session).and_return(user_session)
      allow(view).to receive(:in_multi_mfa_selection_flow?).and_return(false)
      assign(:platform_authenticator, platform_authenticator)
      assign(:user_session, user_session)
      assign(:presenter, presenter)
    end

    it 'displays warning alert' do
      render

      expect(rendered).to have_content(I18n.t('forms.webauthn_platform_setup.warning_text'))
    end
  end
end
