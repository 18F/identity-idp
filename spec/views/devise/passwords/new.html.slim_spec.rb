require 'rails_helper'

describe 'devise/passwords/new.html.slim' do
  before do
    @password_reset_email_form = PasswordResetEmailForm.new('')
    @sp = build_stubbed(
      :service_provider,
      friendly_name: 'Awesome Application!',
      return_to_sp_url: 'www.awesomeness.com'
    )
    view_context = ActionController::Base.new.view_context
    @decorated_session = DecoratedSession.new(
      sp: @sp,
      view_context: view_context,
      sp_session: {},
      service_provider_request: ServiceProviderRequest.new
    ).call
    allow(view).to receive(:decorated_session).and_return(@decorated_session)
  end

  it 'has a localized title' do
    expect(view).to receive(:title).with(t('titles.passwords.forgot'))

    render
  end

  it 'has a localized header' do
    render

    expect(rendered).to have_selector('h1', text: t('headings.passwords.forgot'))
  end

  it 'sets form autocomplete to off' do
    render

    expect(rendered).to have_xpath("//form[@autocomplete='off']")
  end

  it 'has a cancel link that points to the decorated_session cancel_link_url' do
    render

    expect(rendered).to have_link(t('links.cancel'), href: @decorated_session.cancel_link_url)
  end

  it 'has sp alert for certain service providers' do
    @sp.friendly_name = ServiceProviderSessionDecorator::SP_ALERTS.keys.first

    render

    expect(rendered).to have_selector('.alert')
  end

  it 'does not have an sp alert for service providers without alert messages' do
    render

    expect(rendered).to_not have_selector('.alert')
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
