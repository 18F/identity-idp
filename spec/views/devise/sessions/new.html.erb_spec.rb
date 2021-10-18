require 'rails_helper'

describe 'devise/sessions/new.html.erb' do
  before do
    allow(view).to receive(:resource).and_return(build_stubbed(:user))
    allow(view).to receive(:resource_name).and_return(:user)
    allow(view).to receive(:devise_mapping).and_return(Devise.mappings[:user])
    allow(view).to receive(:controller_name).and_return('sessions')
    allow(view).to receive(:decorated_session).and_return(SessionDecorator.new)
    allow_any_instance_of(ActionController::TestRequest).to receive(:path).
      and_return('/')
    assign(:ial, 1)
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
    expect(view).to receive(:title).with(t('titles.visitors.index'))

    render
  end

  it 'includes a link to log in' do
    render

    expect(rendered).to have_content(t('headings.sign_in_without_sp'))
  end

  it 'includes a link to create a new account' do
    render

    expect(rendered).
      to have_link(
        t('links.create_account'), href: sign_up_email_url(request_id: nil)
      )
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
      @decorated_session = DecoratedSession.new(
        sp: sp,
        view_context: view_context,
        sp_session: {},
        service_provider_request: ServiceProviderRequest.new,
      ).call
      allow(view).to receive(:decorated_session).and_return(@decorated_session)
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
        t('links.back_to_sp', sp: 'Awesome Application!'), href: return_to_sp_cancel_path
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

        expect(rendered).to_not have_selector('.usa-alert')
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

  context 'during the acuant maintenance window' do
    let(:start) { Time.zone.parse('2020-01-01T00:00:00Z') }
    let(:now) { Time.zone.parse('2020-01-01T12:00:00Z') }
    let(:finish) { Time.zone.parse('2020-01-01T23:59:59Z') }

    before do
      allow(IdentityConfig.store).to receive(:acuant_maintenance_window_start).and_return(start)
      allow(IdentityConfig.store).to receive(:acuant_maintenance_window_finish).and_return(finish)
    end

    around do |ex|
      travel_to(now) { ex.run }
    end

    it 'renders the warning banner and the normal form' do
      render

      expect(rendered).to have_content('We are currently under maintenance')
      expect(rendered).to have_selector('input.email')
    end
  end
end
