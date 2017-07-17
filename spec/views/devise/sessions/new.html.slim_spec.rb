require 'rails_helper'

describe 'devise/sessions/new.html.slim' do
  before do
    allow(view).to receive(:resource).and_return(build_stubbed(:user))
    allow(view).to receive(:resource_name).and_return(:user)
    allow(view).to receive(:devise_mapping).and_return(Devise.mappings[:user])
    allow(view).to receive(:controller_name).and_return('sessions')
    allow(view).to receive(:decorated_session).and_return(SessionDecorator.new)
  end

  it 'sets autocomplete attribute off' do
    render

    expect(rendered).to match(/<form autocomplete="off"/)
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

  it 'includes a link to security / privacy page' do
    render

    expect(rendered).
      to have_link(t('notices.terms_of_service.link'), href: MarketingSite.privacy_url)

    expect(rendered).to have_selector("a[href='#{MarketingSite.privacy_url}'][target='_blank']")
  end

  context 'when SP is present' do
    before do
      sp = build_stubbed(
        :service_provider,
        friendly_name: 'Awesome Application!',
        return_to_sp_url: 'www.awesomeness.com'
      )
      view_context = ActionController::Base.new.view_context
      @decorated_session = DecoratedSession.new(
        sp: sp,
        view_context: view_context,
        sp_session: {},
        service_provider_request: ServiceProviderRequest.new
      ).call
      allow(view).to receive(:decorated_session).and_return(@decorated_session)
    end

    it 'displays a custom header' do
      render

      expect(rendered).to have_content(
        t('headings.sign_in_with_sp', sp: 'Awesome Application!')
      )
    end

    it 'displays a back to sp link' do
      render

      expect(rendered).to have_link(
        t('links.back_to_sp', sp: 'Awesome Application!'), href: @decorated_session.sp_return_url
      )
    end
  end

  context 'when SP is not present' do
    it 'does not display the branded content' do
      render

      expect(rendered).not_to have_content(
        t('headings.sign_in_with_sp', sp: 'Awesome Application!')
      )
      expect(rendered).not_to have_link(
        t('links.back_to_sp', sp: 'Awesome Application!')
      )
    end
  end
end
