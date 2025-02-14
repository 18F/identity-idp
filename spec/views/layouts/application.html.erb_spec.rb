require 'rails_helper'

RSpec.describe 'layouts/application.html.erb' do
  include Devise::Test::ControllerHelpers

  let(:title_content) { 'Example' }

  before do
    allow(view).to receive(:decorated_sp_session).and_return(
      ServiceProviderSessionCreator.new(
        sp: nil,
        view_context: nil,
        sp_session: {},
        service_provider_request: ServiceProviderRequestProxy.new,
      ).create_session,
    )
    allow(view.request).to receive(:original_fullpath).and_return('/foobar')
    allow(view).to receive(:user_fully_authenticated?).and_return(false)
    view.title = title_content if title_content
  end

  context 'no content for nav present' do
    it 'displays only the logo' do
      render

      expect(rendered).to have_css('.page-header--basic')
      expect(rendered).to_not have_content(t('account.welcome'))
      expect(rendered).to_not have_button(t('links.sign_out'))
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
    context 'without title' do
      let(:title_content) { nil }

      context 'when raise_on_missing_title is false' do
        before do
          allow(IdentityConfig.store).to receive(:raise_on_missing_title).and_return(false)
        end

        it 'notifies NewRelic' do
          expect(NewRelic::Agent).to receive(:notice_error) do |error|
            expect(error).to be_kind_of(ApplicationHelper::MissingTitleError)
            expect(error.message).to include('Missing title')
          end

          expect { render }.to_not raise_error
        end
      end

      context 'when raise_on_missing_title is true' do
        before do
          allow(IdentityConfig.store).to receive(:raise_on_missing_title).and_return(true)
        end

        it 'raises' do
          expect { render }.to raise_error do |error|
            expect(error).to be_kind_of(ActionView::TemplateError)
            expect(error.cause).to be_kind_of(ApplicationHelper::MissingTitleError)
            expect(error.message).to include('Missing title')
          end
        end
      end
    end

    context 'with escapable html' do
      let(:title_content) { "Something with 'single quotes'" }

      it 'does not double-escape HTML' do
        render

        doc = Nokogiri::HTML(rendered)
        expect(doc.at_css('title').text).to eq("Something with 'single quotes' | #{APP_NAME}")
      end
    end

    context 'with html opening or closing syntax' do
      let(:title_content) { 'Symbols <>' }

      it 'properly encodes text' do
        render

        doc = Nokogiri::HTML(rendered)
        expect(doc.at_css('title').text).to eq("Symbols <> | #{APP_NAME}")
      end
    end
  end

  context 'session expiration' do
    it 'renders a javascript page refresh' do
      allow(view).to receive(:current_user).and_return(false)
      allow(view).to receive(:decorated_sp_session).and_return(NullServiceProviderSession.new)
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

  describe 'javascript error tracking' do
    context 'when browser is unsupported' do
      before do
        allow(BrowserSupport).to receive(:supported?).and_return(false)
      end

      it 'does not render error tracking script' do
        render

        expect(rendered).not_to have_css('script[src$="track-errors.js"]', visible: :all)
      end
    end

    context 'when browser is supported' do
      before do
        allow(BrowserSupport).to receive(:supported?).and_return(true)
      end

      it 'renders error tracking script' do
        render

        expect(rendered).to have_css('script[src$="track-errors.js"]', visible: :all)
      end
    end
  end

  describe 'loading recaptcha script' do
    context 'when not on the sign in view' do
      let(:recaptcha_site_key) { 'site_key' }
      before do
        allow(BrowserSupport).to receive(:supported?).and_return(true)
        allow(IdentityConfig.store).to receive(:recaptcha_site_key).and_return(recaptcha_site_key)
      end

      it 'does not load recaptcha script' do
        render

        expect(rendered).to_not have_css('script[src$="enterprise.js"]', visible: :all)
        expect(rendered).to_not have_css('script[src$="api.js"]', visible: :all)
      end
    end
  end
end
