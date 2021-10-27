require 'rails_helper'

describe 'sign_up/completions/show.html.erb' do
  before do
    @user = User.new
    @view_model = SignUpCompletionsShow.new(
      current_user: @user,
      ial2_requested: false,
      decorated_session: SessionDecorator.new,
      handoff: false,
      ialmax_requested: false,
      consent_has_expired: false,
    )
  end

  it 'lists the users multiple sps' do
    identities = create_identities(@user, 3)
    render
    identities.each do |identity|
      expect(rendered).to have_content(identity.agency_name)
    end
    expect(rendered).to have_content(t('idv.messages.agencies_login'))
  end

  it 'shows the users service_provider' do
    identity = create_identities(@user).first
    render
    content = strip_tags(
      t('idv.messages.agency_login_html', sp: identity.display_name),
    )
    expect(rendered).to have_content(content)
  end

  context 'loging into sp for the first time after account creation' do
    before do
      @view_model = SignUpCompletionsShow.new(
        current_user: @user,
        ial2_requested: false,
        decorated_session: SessionDecorator.new,
        handoff: true,
        ialmax_requested: false,
        consent_has_expired: false,
      )
      create_identities(@user)
    end

    it 'informs user they are logging into an SP for the first time' do
      render
      expect(rendered).to have_content(t('titles.sign_up.new_sp'))
    end
  end

  context 'signing in through an SP' do
    let(:service_provider) do
      create(
        :service_provider,
        friendly_name: 'My Agency App',
        agency: create(:agency, name: 'Department of Agencies'),
      )
    end

    let(:view_context) { ActionController::Base.new.view_context }
    let(:decorated_session) do
      ServiceProviderSessionDecorator.new(
        sp: service_provider,
        view_context: view_context,
        sp_session: {
          requested_attributes: [:email],
        },
        service_provider_request: ServiceProviderRequestProxy.new,
      )
    end

    before do
      @user.save!
      @view_model = SignUpCompletionsShow.new(
        current_user: @user,
        ial2_requested: false,
        decorated_session: decorated_session,
        handoff: true,
        ialmax_requested: false,
        consent_has_expired: false,
      )
      allow(view).to receive(:decorated_session).and_return(decorated_session)
      assign(:pii, {})
    end

    it 'shows the app name, not the agency name' do
      render

      text = view_context.strip_tags(rendered)
      expect(text).to include('My Agency App')
      expect(text).to_not include('Department of Agencies')
      expect(text).to include(
        I18n.t(
          'help_text.requested_attributes.intro_html',
          app_name: APP_NAME, sp: 'My Agency App',
        ),
      )
    end
  end

  private

  def create_identities(user, count = 0)
    (0..count).map do |index|
      sp = create(
        :service_provider,
        friendly_name: "SP app #{index}",
        agency: create(:agency, name: "Agency #{index}"),
      )
      create(:service_provider_identity, service_provider: sp.issuer, user: user)
    end
  end
end
