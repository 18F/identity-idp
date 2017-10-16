require 'rails_helper'

describe 'layouts/application.html.slim' do
  include Devise::Test::ControllerHelpers

  before do
    allow(view).to receive(:user_fully_authenticated?).and_return(true)
    allow(view).to receive(:decorated_session).and_return(
      DecoratedSession.new(
        sp: nil,
        view_context: nil,
        sp_session: {},
        service_provider_request: ServiceProviderRequest.new
      ).call
    )
    allow(view.request).to receive(:original_fullpath).and_return('/foobar')
    allow(view).to receive(:current_user).and_return(User.new)
    controller.request.path_parameters[:controller] = 'users/sessions'
    controller.request.path_parameters[:action] = 'new'
  end

  context 'no content for nav present' do
    it 'displays only the logo' do
      render

      expect(rendered).to have_xpath('//nav[contains(@class, "bg-light-blue")]')
      expect(rendered).to_not have_content(t('account.welcome'))
      expect(rendered).to_not have_link(t('links.sign_out'), href: destroy_user_session_path)
    end
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

  context '<title>' do
    it 'does not double-escape HTML in the title tag' do
      view.title("Something with 'single quotes'")

      render

      doc = Nokogiri::HTML(rendered)
      expect(doc.at_css('title').text).to eq("login.gov - Something with 'single quotes'")
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
        DecoratedSession.new(
          sp: nil,
          view_context: nil,
          sp_session: {},
          service_provider_request: nil
        ).call
      )
      allow(Figaro.env).to receive(:participate_in_dap).and_return('true')

      render

      expect(view).to render_template(partial: 'shared/_dap_analytics')
    end
  end

  context 'user is fully authenticated' do
    it 'does not render the DAP analytics' do
      allow(Figaro.env).to receive(:participate_in_dap).and_return('true')

      render

      expect(view).not_to render_template(partial: 'shared/_dap_analytics')
    end
  end

  context 'current_user is present but is not fully authenticated' do
    before do
      allow(view).to receive(:user_fully_authenticated?).and_return(false)
      allow(view).to receive(:decorated_session).and_return(SessionDecorator.new)
    end

    it 'does not render the DAP analytics' do
      allow(Figaro.env).to receive(:participate_in_dap).and_return('true')

      render

      expect(view).not_to render_template(partial: 'shared/_dap_analytics')
    end
  end

  context 'when new relic browser key and app id are present' do
    it 'it render the new relic javascript' do
      allow(Figaro.env).to receive(:newrelic_browser_key).and_return('foo')
      allow(Figaro.env).to receive(:newrelic_browser_app_id).and_return('foo')

      render

      expect(view).to render_template(partial: 'shared/newrelic/_browser_instrumentation')
    end
  end

  context 'when new relic browser key and app id are not present' do
    it 'it does not render the new relic javascript' do
      allow(Figaro.env).to receive(:newrelic_browser_key).and_return('')
      allow(Figaro.env).to receive(:newrelic_browser_app_id).and_return('')

      render

      expect(view).to_not render_template(partial: 'shared/newrelic/_browser_instrumentation')
    end
  end
end
