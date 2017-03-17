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
      allow(view).to receive(:decorated_session).and_return(SessionDecorator.new)
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

  context 'user is not authenticated' do
    it 'displays the DAP analytics' do
      allow(view).to receive(:current_user).and_return(nil)
      allow(view).to receive(:user_fully_authenticated?).and_return(false)
      allow(view).to receive(:decorated_session).and_return(
        DecoratedSession.new(sp: nil, view_context: nil).call
      )
      allow(Figaro.env).to receive(:participate_in_dap).and_return('true')

      render

      expect(view).to render_template(partial: 'shared/_dap_analytics')
    end
  end

  context 'user is fully authenticated' do
    it 'displays the navbar component' do
      render

      expect(rendered).to have_xpath('//nav[@class="bg-white"]')
    end

    it 'does not render the DAP analytics' do
      allow(Figaro.env).to receive(:participate_in_dap).and_return('true')

      render

      expect(view).not_to render_template(partial: 'shared/_dap_analytics')
    end
  end

  context 'user is not fully authenticated' do
    before do
      allow(view).to receive(:user_fully_authenticated?).and_return(false)
      allow(view).to receive(:decorated_session).and_return(SessionDecorator.new)
    end

    it 'displays only the logo' do
      render

      expect(rendered).to have_xpath('//nav[contains(@class, "bg-light-blue")]')
      expect(rendered).to_not have_link(t('shared.nav_auth.my_account'), href: profile_path)
      expect(rendered).to_not have_content(t('shared.nav_auth.welcome'))
      expect(rendered).to_not have_link(t('links.sign_out'), href: destroy_user_session_path)
    end

    it 'renders the DAP analytics' do
      allow(Figaro.env).to receive(:participate_in_dap).and_return('true')

      render

      expect(view).not_to render_template(partial: 'shared/_dap_analytics')
    end
  end

  context 'user fully authenticated' do
    context 'user referred to IDP by an SP' do
      it 'does not show the auth nav bar' do
        allow(view).to receive(:decorated_session).and_return(SessionDecorator.new)
        allow(view).to receive(:user_fully_authenticated?).and_return(true)
        sp_session = { sp: 'stuff' }
        allow(view).to receive(:session).and_return(sp_session)

        render

        expect(view).to_not render_template(partial: '_nav_auth')
      end
    end

    context 'user not referred to IDP by an SP' do
      it 'shows the auth nav bar' do
        allow(view).to receive(:user_fully_authenticated?).and_return(true)
        allow(view).to receive(:session).and_return({})

        render

        expect(view).to render_template(partial: '_nav_auth')
      end
    end
  end

  context 'user not fully authenticated' do
    it 'does not shos the auth nav bar' do
      allow(view).to receive(:decorated_session).and_return(SessionDecorator.new)
      allow(view).to receive(:user_fully_authenticated?).and_return(false)

      render

      expect(view).to_not render_template(partial: '_i18n_mode')
    end
  end
end
