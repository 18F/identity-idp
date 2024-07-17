require 'rails_helper'

RSpec.describe 'devise/sessions/new.html.erb' do
  include UserAgentHelper

  before do
    allow(view).to receive(:resource).and_return(build_stubbed(:user))
    allow(view).to receive(:resource_name).and_return(:user)
    allow(view).to receive(:devise_mapping).and_return(Devise.mappings[:user])
    allow(view).to receive(:controller_name).and_return('sessions')
    allow(view).to receive(:decorated_sp_session).and_return(NullServiceProviderSession.new)
    allow_any_instance_of(ActionController::TestRequest).to receive(:path).
      and_return('/')
  end

  it 'sets autocomplete attribute off' do
    render

    expect(rendered).to match(/<form[^>]*autocomplete="off"/)
  end

  it 'sets input autocorrect to off' do
    render

    expect(rendered).to have_xpath("//input[@autocorrect='off']")
  end

  it 'has a localized title' do
    expect(view).to receive(:title=).with(t('titles.visitors.index'))

    render
  end

  it 'has a localized page heading' do
    render

    expect(rendered).to have_selector('h1', text: t('headings.sign_in_existing_users'))
  end

  it 'includes a link to create a new account' do
    render

    expect(rendered).to have_link(t('links.create_account'), href: sign_up_email_url)
  end

  it 'includes a link to create a new account' do
    render

    expect(rendered).to have_link(t('links.create_account'), href: sign_up_email_url)
  end

  it 'includes a link to security / privacy page and privacy statement act' do
    render

    expect(rendered).
      to have_link(
        t('notices.privacy.security_and_privacy_practices'),
        href: MarketingSite.security_and_privacy_practices_url,
      )
    expect(rendered).
      to have_selector(
        "a[href='#{MarketingSite.security_and_privacy_practices_url}']\
[target='_blank'][rel='noopener noreferrer']",
      )

    expect(rendered).
      to have_link(
        t('notices.privacy.privacy_act_statement'),
        href: MarketingSite.privacy_act_statement_url,
      )
    expect(rendered).to have_selector(
      "a[href='#{MarketingSite.privacy_act_statement_url}']\
[target='_blank'][rel='noopener noreferrer']",
    )
  end

  context 'when SP is present' do
    let(:sp) do
      build_stubbed(
        :service_provider,
        friendly_name: 'Awesome Application!',
        return_to_sp_url: 'www.awesomeness.com',
      )
    end
    before do
      view_context = ActionController::Base.new.view_context
      @decorated_sp_session = ServiceProviderSessionCreator.new(
        sp: sp,
        view_context: view_context,
        sp_session: {},
        service_provider_request: ServiceProviderRequest.new,
      ).create_session
      allow(view).to receive(:decorated_sp_session).and_return(@decorated_sp_session)
      allow(view_context).to receive(:sign_up_email_path).
        and_return('/sign_up/enter_email')
    end

    it 'displays a custom header' do
      render

      sp_content = [
        'Awesome Application!',
        t('headings.create_account_with_sp.sp_text', app_name: APP_NAME),
      ].join(' ')

      expect(rendered).to have_content(sp_content, normalize_ws: true)
    end

    it 'displays a back to sp link' do
      render

      expect(rendered).to have_link(
        t(
          'links.back_to_sp',
          sp: 'Awesome Application!',
        ), href: return_to_sp_cancel_path(step: :authentication)
      )
    end

    it 'has sp alert for certain service providers' do
      render

      expect(rendered).to have_selector(
        '.usa-alert',
        text: 'custom sign in help text for Awesome Application!',
      )
    end

    context 'service provider does not have custom help text' do
      let(:sp) do
        build_stubbed(
          :service_provider_without_help_text,
          friendly_name: 'Awesome Application!',
          return_to_sp_url: 'www.awesomeness.com',
        )
      end

      it 'does not have an sp alert for service providers without alert messages' do
        render

        expect(rendered).to_not have_selector(
          '.usa-alert',
          text: 'custom sign in help text for Awesome Application!',
        )
      end
    end
  end

  context 'when SP is not present' do
    it 'does not display the branded content' do
      render

      expect(rendered).not_to have_content(
        t('headings.sign_in_with_sp', sp: 'Awesome Application!'),
      )
      expect(rendered).not_to have_link(
        t('links.back_to_sp', sp: 'Awesome Application!'),
      )
    end
  end

  context 'on mobile' do
    before do
      mobile_device = Browser.new(mobile_user_agent)
      allow(BrowserCache).to receive(:parse).and_return(mobile_device)
    end

    it 'does not show PIV/CAC sign-in link' do
      render

      expect(rendered).to_not have_link t('account.login.piv_cac')
    end
  end

  describe 'DAP analytics' do
    let(:participate_in_dap) { false }

    before do
      allow(IdentityConfig.store).to receive(:participate_in_dap).and_return(participate_in_dap)
    end

    context 'when configured to not participate in dap' do
      let(:participate_in_dap) { false }

      it 'does not render DAP analytics' do
        allow(view).to receive(:javascript_packs_tag_once)
        expect(view).not_to receive(:javascript_packs_tag_once).
          with(a_string_matching('https://dap.digitalgov.gov/'), async: true, id: '_fed_an_ua_tag')

        render
      end
    end

    context 'when configured to participate in dap' do
      let(:participate_in_dap) { true }

      it 'renders DAP analytics' do
        allow(view).to receive(:javascript_packs_tag_once)
        expect(view).to receive(:javascript_packs_tag_once).with(
          a_string_matching('https://dap.digitalgov.gov/'),
          async: true,
          preload_links_header: false,
          id: '_fed_an_ua_tag',
        )

        render
      end
    end
  end

  describe 'submit button' do
    let(:sign_in_recaptcha_enabled) { false }
    let(:recaptcha_mock_validator) { false }

    subject(:rendered) { render }

    before do
      allow(FeatureManagement).to receive(:sign_in_recaptcha_enabled?).
        and_return(sign_in_recaptcha_enabled)
      allow(IdentityConfig.store).to receive(:recaptcha_mock_validator).
        and_return(recaptcha_mock_validator)
    end

    context 'recaptcha at sign in is disabled' do
      let(:sign_in_recaptcha_enabled) { false }

      it 'renders default sign-in submit button' do
        expect(rendered).to have_button(t('links.sign_in'))
        expect(rendered).not_to have_css('lg-captcha-submit-button')
      end

      context 'recaptcha mock validator is enabled' do
        let(:recaptcha_mock_validator) { true }

        it 'renders captcha sign-in submit button' do
          expect(rendered).to have_button(t('links.sign_in'))
          expect(rendered).to have_css('lg-captcha-submit-button')
        end
      end
    end

    context 'recaptcha at sign in is enabled' do
      let(:sign_in_recaptcha_enabled) { true }

      it 'renders captcha sign-in submit button' do
        expect(rendered).to have_button(t('links.sign_in'))
        expect(rendered).to have_css('lg-captcha-submit-button')
      end
    end
  end
end
