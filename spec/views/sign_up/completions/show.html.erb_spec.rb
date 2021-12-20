require 'rails_helper'

describe 'sign_up/completions/show.html.erb' do
  let(:service_provider) do
    create(
      :service_provider,
      friendly_name: 'My Agency App',
      agency: create(:agency, name: 'Department of Agencies'),
    )
  end
  let(:view_context) { ActionController::Base.new.view_context }
  let(:requested_attributes) { [:email] }
  let(:current_user) { create(:user, :signed_up) }
  let(:decorated_session) do
    ServiceProviderSessionDecorator.new(
      sp: service_provider,
      view_context: view_context,
      sp_session: {
        requested_attributes: requested_attributes,
      },
      service_provider_request: ServiceProviderRequestProxy.new,
    )
  end
  let(:view_model) do
    SignUpCompletionsShow.new(
      current_user: current_user,
      ial2_requested: false,
      decorated_session: decorated_session,
      handoff: true,
      ialmax_requested: false,
      consent_has_expired: false,
    )
  end

  before do
    allow(view).to receive(:decorated_session).and_return(decorated_session)
    assign(:pii, { email: 'foo@example.com', all_emails: ['foo@example.com', 'bar@example.com'] })
    assign(:view_model, view_model)
  end

  it 'informs user they are logging into an SP for the first time' do
    render
    expect(rendered).to have_content(t('titles.sign_up.new_sp'))
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

  context 'the all_emails scope is requested' do
    let(:requested_attributes) { [:email, :all_emails] }

    it 'renders all of the user email addresses' do
      render

      expect(rendered).to include(t('help_text.requested_attributes.all_emails'))
      expect(rendered).to include('foo@example.com')
      expect(rendered).to include('bar@example.com')
    end
  end

  it 'shows the recovery alert if the user only has 1 mfa method' do
    render

    expect(rendered).to include(t('two_factor_authentication.recovery_alert.details'))
  end

  it 'does not show the recovery alert if the user has multiple mfa methods' do
    create(:phone_configuration, user: current_user)

    render

    expect(rendered).to_not include(t('two_factor_authentication.recovery_alert.details'))
  end
end
