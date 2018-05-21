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
end
