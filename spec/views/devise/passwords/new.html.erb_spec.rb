require 'rails_helper'

RSpec.describe 'devise/passwords/new.html.erb' do
  let(:sp) do
    build_stubbed(
      :service_provider,
      friendly_name: 'Awesome Application!',
      return_to_sp_url: 'www.awesomeness.com',
    )
  end
  before do
    @password_reset_email_form = PasswordResetEmailForm.new('')
    view_context = ActionController::Base.new.view_context
    allow(view_context).to receive(:new_user_session_url).
      and_return('https://www.example.com/')
    allow(view_context).to receive(:sign_up_email_path).
      and_return('/sign_up/enter_email')
    allow_any_instance_of(ActionController::TestRequest).to receive(:path).
      and_return('/users/password/new')

    @decorated_sp_session = ServiceProviderSessionCreator.new(
      sp:,
      view_context:,
      sp_session: {},
      service_provider_request: ServiceProviderRequestProxy.new,
    ).create_session
    allow(view).to receive(:decorated_sp_session).and_return(@decorated_sp_session)
  end

  it 'has a localized title' do
    expect(view).to receive(:title=).with(t('titles.passwords.forgot'))

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

  it 'sets input autocorrect to off' do
    render

    expect(rendered).to have_xpath("//input[@autocorrect='off']")
  end

  it 'has a cancel link that points to the decorated_sp_session cancel_link_url' do
    render

    expect(rendered).to have_link(t('links.cancel'), href: @decorated_sp_session.cancel_link_url)
  end

  it 'has sp alert for certain service providers' do
    render

    expect(rendered).to have_selector(
      '.usa-alert',
      text: 'custom forgot password help text for Awesome Application!',
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
