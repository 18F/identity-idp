require 'rails_helper'

describe 'layouts/application.html.slim' do
  include Devise::Test::ControllerHelpers

  before do
    allow(view).to receive(:user_fully_authenticated?).and_return(true)
    allow(view.request).to receive(:original_url).and_return('http://test.host/foobar')
    allow(view).to receive(:current_user).and_return(User.new)
  end

  context 'when i18n mode enabled' do
    before do
      allow(FeatureManagement).to receive(:enable_i18n_mode?).and_return(true)
    end

    after do
      allow(FeatureManagement).to receive(:enable_i18n_mode?).and_return(false)
    end

    it 'renders _i18n_mode.html' do
      render

      expect(view).to render_template(partial: '_i18n_mode')
    end
  end

  context 'when i18n mode disabled' do
    before do
      allow(FeatureManagement).to receive(:enable_i18n_mode?).and_return(false)
    end

    it 'does not render _i18n_mode.html' do
      render

      expect(view).to_not render_template(partial: '_i18n_mode')
    end
  end

  context 'session expiration' do
    it 'renders a javascript page refresh' do
      allow(view).to receive(:user_fully_authenticated?).and_return(false)
      allow(view).to receive(:current_user).and_return(false)
      render

      expect(view).to render_template(partial: 'session_timeout/_expire_session')
    end

    context 'with skip_session_expiration' do
      before { assign(:skip_session_expiration, true) }

      it 'does not render a javascript page refresh' do
        render

        expect(view).to_not render_template(partial: 'session_timeout/_expire_session')
      end
    end
  end

  it 'displays the navbar component when user is fully authenticated' do
    render
    expect(rendered).to have_xpath('//nav[@class="bg-white"]')
  end

  it 'displays only the logo when user is not fully authenticated' do
    allow(view).to receive(:user_fully_authenticated?).and_return(false)
    render

    expect(rendered).to have_xpath('//nav[contains(@class, "bg-light-blue")]')
    expect(rendered).to_not have_link(t('shared.nav_auth.my_account'), href: profile_path)
    expect(rendered).to_not have_content(t('shared.nav_auth.welcome'))
    expect(rendered).to_not have_link(t('links.sign_out'), href: destroy_user_session_path)
  end
end
