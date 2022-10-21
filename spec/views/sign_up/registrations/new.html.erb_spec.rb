require 'rails_helper'

describe 'sign_up/registrations/new.html.erb' do
  let(:sp) do
    build_stubbed(
      :service_provider,
      friendly_name: 'Awesome Application!',
      return_to_sp_url: 'www.awesomeness.com',
    )
  end
  before do
    allow(view).to receive(:current_user).and_return(nil)
    @register_user_email_form = RegisterUserEmailForm.new(
      analytics: FakeAnalytics.new,
      attempts_tracker: IrsAttemptsApiTrackingHelper::FakeAttemptsTracker.new,
    )
    view_context = ActionController::Base.new.view_context
    allow(view_context).to receive(:new_user_session_url).
      and_return('https://www.example.com/')
    allow(view_context).to receive(:sign_up_email_path).
      and_return('/sign_up/enter_email')
    allow_any_instance_of(ActionView::Base).to receive(:request_id).
      and_return(nil)

    @decorated_session = DecoratedSession.new(
      sp: sp,
      view_context: view_context,
      sp_session: {},
      service_provider_request: ServiceProviderRequestProxy.new,
    ).call
    allow(view).to receive(:decorated_session).and_return(@decorated_session)
  end

  it 'has a localized title' do
    expect(view).to receive(:title).with(t('titles.registrations.new'))

    render
  end

  it 'has a localized header' do
    render

    expect(rendered).to have_selector('h1', text: t('titles.registrations.new'))
  end

  it 'sets form autocomplete to off' do
    render

    expect(rendered).to have_xpath("//form[@autocomplete='off']")
  end

  it 'sets input autocorrect to off' do
    render

    expect(rendered).to have_xpath("//input[@autocorrect='off']")
  end

  it 'has a cancel link that points to the decorated_session cancel_link_url' do
    render

    expect(rendered).to have_link(t('links.cancel'), href: @decorated_session.cancel_link_url)
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
  end
end
