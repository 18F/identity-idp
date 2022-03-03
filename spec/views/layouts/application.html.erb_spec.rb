require 'rails_helper'

describe 'layouts/application.html.erb' do
  include Devise::Test::ControllerHelpers

  before do
    allow(view).to receive(:user_fully_authenticated?).and_return(true)
    allow(view).to receive(:decorated_session).and_return(
      DecoratedSession.new(
        sp: nil,
        view_context: nil,
        sp_session: {},
        service_provider_request: ServiceProviderRequestProxy.new,
      ).call,
    )
    allow(view.request).to receive(:original_fullpath).and_return('/foobar')
    allow(view).to receive(:current_user).and_return(User.new)
    controller.request.path_parameters[:controller] = 'users/sessions'
    controller.request.path_parameters[:action] = 'new'
  end

  context 'no content for nav present' do
    it 'displays only the logo' do
      render

      expect(rendered).to have_css('.page-header--basic')
      expect(rendered).to_not have_content(t('account.welcome'))
      expect(rendered).to_not have_link(t('links.sign_out'), href: destroy_user_session_path)
    end
  end

  context 'when FeatureManagement.show_demo_banner? is true' do
    it 'displays the demo banner' do
      allow(FeatureManagement).to receive(:show_demo_banner?).and_return(true)
      render

      expect(rendered).to have_content('DEMO')
    end
  end

  context 'when FeatureManagement.show_demo_banner? is false' do
    it 'does not display the demo banner' do
      allow(FeatureManagement).to receive(:show_demo_banner?).and_return(false)
      render

      expect(rendered).to_not have_content('DEMO')
    end
  end

  context 'when FeatureManagement.show_no_pii_banner? is true' do
    it 'displays the no PII banner' do
      allow(FeatureManagement).to receive(:show_no_pii_banner?).and_return(true)
      render

      expect(rendered).to have_content('Do not use real personal information')
    end
  end

  context 'when FeatureManagement.show_no_pii_banner? is false' do
    it 'does not display the no PII banner' do
      allow(FeatureManagement).to receive(:show_no_pii_banner?).and_return(false)
      render

      expect(rendered).to_not have_content('Do not use real personal information')
    end
  end

  context '<title>' do
    context 'with a page title added' do
      it 'does not double-escape HTML in the title tag' do
        view.title("Something with 'single quotes'")

        render

        doc = Nokogiri::HTML(rendered)
        expect(doc.at_css('title').text).to include("Something with 'single quotes' - Login.gov")
      end

      it 'properly works with > in the title tag' do
        view.title('Symbols <>')

        render

        doc = Nokogiri::HTML(rendered)
        expect(doc.at_css('title').text).to include('Symbols <> - Login.gov')
      end
    end

    context 'without a page title added' do
      it 'should only have Login.gov as title' do
        render

        doc = Nokogiri::HTML(rendered)
        expect(doc.at_css('title').text).to include('Login.gov')
      end
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

  context 'user is not authenticated and is not on page with trust' do
    it 'displays the DAP analytics' do
      allow(view).to receive(:current_user).and_return(nil)
      allow(view).to receive(:page_with_trust?).and_return(false)
      allow(view).to receive(:user_fully_authenticated?).and_return(false)
      allow(view).to receive(:decorated_session).and_return(
        DecoratedSession.new(
          sp: nil,
          view_context: nil,
          sp_session: {},
          service_provider_request: nil,
        ).call,
      )
      allow(IdentityConfig.store).to receive(:participate_in_dap).and_return(true)

      render

      expect(view).to render_template(partial: 'shared/_dap_analytics')
    end
  end

  context 'user is fully authenticated' do
    it 'does not render the DAP analytics' do
      allow(IdentityConfig.store).to receive(:participate_in_dap).and_return(true)

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
      allow(IdentityConfig.store).to receive(:participate_in_dap).and_return(true)

      render

      expect(view).not_to render_template(partial: 'shared/_dap_analytics')
    end
  end

  context 'when new relic browser key and app id are present' do
    it 'it render the new relic javascript' do
      allow(IdentityConfig.store).to receive(:newrelic_browser_key).and_return('foo')
      allow(IdentityConfig.store).to receive(:newrelic_browser_app_id).and_return('foo')

      render

      expect(view).to render_template(partial: 'shared/newrelic/_browser_instrumentation')
    end
  end

  context 'when new relic browser key and app id are not present' do
    it 'it does not render the new relic javascript' do
      allow(IdentityConfig.store).to receive(:newrelic_browser_key).and_return('')
      allow(IdentityConfig.store).to receive(:newrelic_browser_app_id).and_return('')

      render

      expect(view).to_not render_template(partial: 'shared/newrelic/_browser_instrumentation')
    end
  end
end
