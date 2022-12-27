require 'rails_helper'

describe 'sign_up/completions/show.html.erb' do
  let(:user) { create(:user, :signed_up) }
  let(:service_provider) { create(:service_provider) }
  let(:decrypted_pii) { {} }
  let(:requested_attributes) { [:email] }
  let(:ial2_requested) { false }
  let(:completion_context) { :new_sp }

  let(:view_context) { ActionController::Base.new.view_context }
  let(:decorated_session) do
    ServiceProviderSessionDecorator.new(
      sp: service_provider,
      view_context: view_context,
      sp_session: {},
      service_provider_request: ServiceProviderRequestProxy.new,
    )
  end

  let(:presenter) do
    CompletionsPresenter.new(
      current_user: user,
      current_sp: service_provider,
      decrypted_pii: decrypted_pii,
      requested_attributes: requested_attributes,
      ial2_requested: ial2_requested,
      completion_context: completion_context,
    )
  end

  before do
    @user = user
    @presenter = presenter
    allow(view).to receive(:decorated_session).and_return(decorated_session)
  end

  it 'shows the app name, not the agency name' do
    render

    text = view_context.strip_tags(rendered)
    expect(text).to include(service_provider.friendly_name)
    expect(text).to_not include(service_provider.agency.name)
    expect(text).to include(
      view_context.strip_tags(
        I18n.t(
          'help_text.requested_attributes.ial1_intro_html',
          sp: service_provider.friendly_name,
        ),
      ),
    )
  end

  context 'the all_emails scope is requested' do
    let(:requested_attributes) { [:email, :all_emails] }

    it 'renders all of the user email addresses' do
      create(:email_address, user: user)
      user.reload

      render

      emails = user.reload.email_addresses.map(&:email)

      expect(rendered).to include(t('help_text.requested_attributes.all_emails'))
      expect(rendered).to include(emails.first)
      expect(rendered).to include(emails.last)
    end
  end

  context 'ial2' do
    let(:ial2_requested) { true }
    let(:requested_attributes) { [:email, :social_security_number] }
    let(:decrypted_pii) do
      {
        first_name: 'Testy',
        last_name: 'Testerson',
        ssn: '900123456',
        address1: '123 main st',
        address2: 'apt 123',
        city: 'Washington',
        state: 'DC',
        zipcode: '20405',
        dob: '1990-01-01',
        phone: '+12022121000',
      }
    end

    it 'masks the SSN' do
      render

      expect(rendered).to include('9**-**-***6')
    end
  end

  describe 'MFA CTA banner' do
    let(:multiple_factors_enabled) { nil }

    before do
      @multiple_factors_enabled = multiple_factors_enabled
    end

    context 'with multiple factors disabled' do
      let(:multiple_factors_enabled) { false }

      it 'shows a banner if the user selects one MFA option' do
        render
        expect(rendered).to have_content(t('mfa.second_method_warning.text'))
      end
    end

    context 'with multiple factors enabled' do
      let(:multiple_factors_enabled) { true }

      it 'does not show a banner' do
        render
        expect(rendered).not_to have_content(t('mfa.second_method_warning.text'))
      end
    end
  end
end
