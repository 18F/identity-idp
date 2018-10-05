require 'rails_helper'

describe 'sign_up/registrations/new.html.slim' do
  before do
    @register_user_email_form = RegisterUserEmailForm.new
    allow(view).to receive(:controller_name).and_return('registrations')
    allow(view).to receive(:current_user).and_return(nil)
    allow(view).to receive(:request_id).and_return(nil)

    view_context = ActionController::Base.new.view_context
    @decorated_session = DecoratedSession.new(
      sp: nil, view_context: view_context, sp_session: {}, service_provider_request: nil
    ).call
    allow(view).to receive(:decorated_session).and_return(@decorated_session)
    allow(view_context).to receive(:root_url).and_return('http://www.example.com')
  end

  it 'has a localized title' do
    expect(view).to receive(:title).with(t('titles.registrations.new'))

    render
  end

  it 'includes a link to terms of service' do
    render

    expect(rendered).
      to have_link(t('notices.terms_of_service.link'), href: MarketingSite.privacy_url)

    expect(rendered).to have_selector("a[href='#{MarketingSite.privacy_url}'][target='_blank']")
  end

  it 'sets form autocomplete to off' do
    render

    expect(rendered).to have_xpath("//form[@autocomplete='off']")
  end

  it 'includes a link to return to the decorated_session cancel_link_url' do
    render

    expect(rendered).to have_link(t('links.cancel'), href: @decorated_session.cancel_link_url)
  end

  it 'does not render a recaptcha with recaptcha disabled' do
    allow(FeatureManagement).to receive(:recaptcha_enabled?).and_return(false)
    render

    expect(rendered).to_not have_selector('#recaptcha')
  end

  it 'renders a recaptcha with recaptcha enabled' do
    allow(FeatureManagement).to receive(:recaptcha_enabled?).and_return(true)
    render

    expect(rendered).to have_selector('#recaptcha')
  end

  context 'when SAM is present' do
    before do
      @sp = build_stubbed(
        :service_provider,
        friendly_name: 'SAM',
        return_to_sp_url: 'www.awesomeness.com'
      )
      view_context = ActionController::Base.new.view_context
      allow(view_context).to receive(:sign_up_start_url).
        and_return('https://www.example.com/sign_up/start')
      @decorated_session = DecoratedSession.new(
        sp: @sp,
        view_context: view_context,
        sp_session: {},
        service_provider_request: ServiceProviderRequest.new
      ).call
      allow(view).to receive(:decorated_session).and_return(@decorated_session)
    end

    it 'displays a custom alert message for SAM' do
      render

      expect(rendered).to \
        have_content(@decorated_session.sp_msg('create_account_page.body'))
    end

    it 'has sp alert for the SAM service provider' do
      @sp.friendly_name = 'SAM'

      render

      expect(rendered).to have_selector('.alert')
    end

    it 'does not have an sp alert for the other service providers' do
      @sp.friendly_name = 'other'
      render

      expect(rendered).to_not have_selector('.alert')
    end

    it 'does not have an sp alert when the path is excluded' do
      @sp.friendly_name = 'CBP Trusted Traveler Programs'
      render

      expect(rendered).to_not have_selector('.alert')
    end
  end

  context 'when SP is not present' do
    it 'does not display the branded content' do
      render

      expect(rendered).not_to \
        have_content(t('service_providers.sam.create_account_page.body'))
    end
  end
end
