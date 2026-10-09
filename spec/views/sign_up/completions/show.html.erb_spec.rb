require 'rails_helper'

RSpec.describe 'sign_up/completions/show.html.erb' do
  include LinkHelper

  let(:user) { create(:user, :proofed) }
  let(:service_provider) { create(:service_provider) }
  let(:selected_email_id) { user.email_addresses.first.id }
  let(:decrypted_pii) { {} }
  let(:requested_attributes) { [:email] }
  let(:idv_requested) { false }
  let(:completion_context) { :new_sp }
  let(:nds_layout) { false }

  let(:view_context) { ActionController::Base.new.view_context }
  let(:decorated_sp_session) do
    ServiceProviderSession.new(
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
      decrypted_pii:,
      requested_attributes:,
      idv_requested:,
      completion_context:,
      selected_email_id:,
      requested_delegation_scopes:,
    )
  end
  let(:requested_delegation_scopes) { [] }

  before do
    allow(view).to receive(:nds_layout?).and_return(nds_layout)
    allow(view).to receive(:current_sp).and_return(service_provider)
    @user = user
    @presenter = presenter
    allow(view).to receive(:decorated_sp_session).and_return(decorated_sp_session)
  end

  it 'shows the app name, not the agency name' do
    render

    text = view_context.strip_tags(rendered)
    expect(text).to include(service_provider.friendly_name)
    expect(text).to_not include(service_provider.agency.name)
    expect(text).to include(
      view_context.strip_tags(
        t(
          'help_text.requested_attributes.intro_html',
          sp_html: content_tag(:strong, service_provider.friendly_name),
        ),
      ),
    )
  end

  it 'shows cancel link on completion screen' do
    render
    expect(rendered).to have_link(
      t('links.cancel'),
      href: sign_up_completed_cancel_path,
    )
  end

  it 'shows how the information will be shared with the sp' do
    render
    expect(rendered).to include(
      t(
        'sign_up.information_sharing_html',
        app_name: APP_NAME,
        link_html: new_tab_link_to(
          t('notices.privacy.privacy_act_statement'),
          MarketingSite.privacy_act_statement_url,
        ),
      ),
    )
  end

  context 'select email to send to partner' do
    it 'shows email change link' do
      render

      expect(rendered).to include(t('help_text.requested_attributes.change_email_link'))
    end
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

  context 'idv' do
    let(:idv_requested) { true }
    let(:requested_attributes) { [:email, :social_security_number, :verified_at] }
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

    it 'renders verified_at in the local timezone' do
      render
      formatted_verified_at = l(
        user.active_profile.verified_at.in_time_zone('UTC'),
        format: t('time.formats.event_timestamp'),
      )
      expect(rendered).to include(formatted_verified_at)
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

  context 'in the NDS layout' do
    let(:nds_layout) { true }
    let(:idv_requested) { true }
    let(:requested_attributes) { %i[email given_name family_name address social_security_number] }
    let(:decrypted_pii) { Pii::Attributes.new_from_hash(Idp::Constants::MOCK_IDV_APPLICANT_WITH_SSN) }

    before { render }

    it 'renders the identity-verified card with summary rows, actions and NIST seal' do
      expect(rendered).to have_css('.auth--form-page h1', text: t('nds.completions.heading_idv'))
      expect(rendered).to have_css(
        '.auth__intro-description strong',
        text: service_provider.friendly_name,
      )
      expect(rendered).to have_css(
        '.card--elevated .nds-summary__label',
        text: t('help_text.requested_attributes.full_name'),
      )
      expect(rendered).to have_css(
        '.card--elevated [data-nds-masked] [data-masked="true"]',
        text: /•••-••-\d{4}/,
      )
      expect(rendered).to have_css(
        '.card--elevated button[type=submit]',
        text: t('forms.buttons.continue'),
      )
      expect(rendered).to have_link(t('links.cancel'), href: sign_up_completed_cancel_path)
      expect(rendered).to have_css("img[src*='nist'][alt='#{t('nds.completions.nist_alt')}']")
    end
  end

  describe 'delegated-access consent' do
    let(:idv_requested) { true }
    let(:requested_attributes) { %i[email] }
    let(:requested_delegation_scopes) { %w[housing_records retirement_benefits] }
    let(:service_provider) do
      create(:service_provider, :delegation_service_provider, friendly_name: 'MyBenefits Assistant')
    end
    let(:housing_agency) do
      create(
        :agency, name: 'Department of Housing Support',
                 delegation_description: { en: 'helps people find and keep housing.' },
                 delegation_learn_more_url: 'https://housing.example.gov/about'
      )
    end
    let!(:housing) do
      create(
        :service_provider, :delegation_application, agency: housing_agency,
                                                    delegation_scope_value: 'housing_records',
                                                    friendly_name: 'Housing Assistance Records',
                                                    delegation_display_name: {
                                                      en: 'Housing Assistance Records',
                                                    }
      )
    end
    let!(:housing_api) do
      create(
        :token_exchange_resource_server, service_provider: housing,
                                         identifier: 'https://records-api.housing.example.gov'
      )
    end
    let!(:retirement) do
      create(
        :service_provider, :delegation_application,
        agency: create(:agency, name: 'National Retirement Administration'),
        delegation_scope_value: 'retirement_benefits',
        delegation_display_name: { en: 'Retirement Benefits Portal' },
        delegation_access_type: 'read_write'
      )
    end

    before { allow(IdentityConfig.store).to receive(:token_exchange_enabled).and_return(true) }

    shared_examples 'renders the locked consent rows' do
      it 'shows who is asking, one locked row per requested application, and the remember box' do
        render

        expect(rendered).to have_content('Office of Benefits Coordination')
        expect(rendered).to have_content(t('sign_up.delegation.uses_ai'))
        expect(rendered).to have_content(
          t('sign_up.delegation.access_duration', sp: 'MyBenefits Assistant', hours: 12),
        )
        expect(rendered).to have_content(
          t('sign_up.delegation.requesting_access', sp: 'MyBenefits Assistant'),
        )
        expect(rendered).to have_css('[data-delegation-agency]', count: 2)
        expect(rendered).to have_content('Department of Housing Support')
        expect(rendered).to have_content('helps people find and keep housing.')
        expect(rendered).to have_css(
          "input[type=checkbox][name='idv_form[delegation_applications][]'][checked][disabled]",
          count: 2,
        )
        expect(rendered).to have_css('[data-delegation-application][data-status="new"]', count: 2)
        expect(rendered).to have_content('Housing Assistance Records')
        expect(rendered).to have_content('https://records-api.housing.example.gov')
        expect(rendered).to have_content(t('sign_up.delegation.access_read_write'))
        expect(rendered).to have_css(
          "input[type=checkbox][name='idv_form[delegation_remember]']:not([checked])",
        )
        expect(rendered).to have_content(t('sign_up.delegation.required_badge'))
      end
    end

    context 'in the legacy layout' do
      let(:nds_layout) { false }
      it_behaves_like 'renders the locked consent rows'

      it 'offers allow-and-continue and a cancel link back to the service provider' do
        render
        expect(rendered).to have_button(t('sign_up.delegation.allow_button'))
        expect(rendered).to have_link(
          t('sign_up.delegation.cancel_button', sp: 'MyBenefits Assistant'),
          href: return_to_sp_cancel_path(step: :sign_up),
        )
      end
    end

    context 'in the NDS layout' do
      let(:nds_layout) { true }
      it_behaves_like 'renders the locked consent rows'
    end

    context 'with an approval made in advance from the account page' do
      let(:nds_layout) { false }
      before do
        TokenExchangeGrant.approve!(
          user:, service_provider:, application: housing, source: 'account_page', remember: true,
        )
      end

      it 'marks that row already approved and the other new' do
        render
        expect(rendered).to have_css(
          '[data-delegation-application][data-status="approved"]',
          count: 1,
        )
        expect(rendered).to have_css('[data-delegation-application][data-status="new"]', count: 1)
        expect(rendered).to have_content(t('sign_up.delegation.status.approved'))
      end
    end

    context 'with an approval made stale by a material content change' do
      let(:nds_layout) { false }
      before do
        TokenExchangeGrant.approve!(
          user:, service_provider:, application: housing, source: 'consent_screen', remember: true,
        )
        housing.update!(consent_content_version: 2, consent_material_version: 2)
      end

      it 'marks that row updated' do
        render
        expect(rendered).to have_css(
          '[data-delegation-application][data-status="updated"]',
          count: 1,
        )
        expect(rendered).to have_content(t('sign_up.delegation.status.updated'))
      end
    end

    context 'when the service provider is not approved for delegation' do
      let(:nds_layout) { true }
      before { service_provider.update!(token_exchange_enabled_sp: false) }

      it 'renders no consent section' do
        render
        expect(rendered).not_to have_css('[data-delegation-consent]')
      end
    end
  end
end
