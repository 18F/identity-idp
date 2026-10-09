require 'rails_helper'

RSpec.describe 'accounts/delegated_access/show.html.erb' do
  let(:user) { create(:user, :fully_registered) }
  let!(:mybenefits) do
    create(:service_provider, :delegation_service_provider, friendly_name: 'MyBenefits Assistant')
  end
  let(:housing_agency) do
    create(
      :agency, name: 'Department of Housing Support',
               delegation_description: { en: 'helps people find and keep housing.' }
    )
  end
  let!(:housing) do
    create(
      :service_provider, :delegation_application, agency: housing_agency,
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
      delegation_display_name: { en: 'Retirement Benefits Portal' },
      delegation_access_type: 'read_write'
    )
  end

  before do
    allow(IdentityConfig.store).to receive(:token_exchange_enabled).and_return(true)
    allow(view).to receive(:current_user).and_return(user)
    @delegated_access = DelegatedAccessPresenter.new(user:)
  end

  it 'renders the service provider card and a checkbox per application, grouped by agency' do
    render

    expect(rendered).to have_content('MyBenefits Assistant')
    expect(rendered).to have_content('Office of Benefits Coordination')
    expect(rendered).to have_css('[data-delegated-access-agency]', count: 2)
    expect(rendered).to have_content('helps people find and keep housing.')
    expect(rendered).to have_css(
      "input[type=checkbox][name='application_ids[]'][value='#{housing.id}']", visible: :all
    )
    expect(rendered).to have_content('https://records-api.housing.example.gov')
    expect(rendered).to have_content(t('sign_up.delegation.access_read_write'))
    expect(rendered).to have_button(t('account.delegated_access.approve_selected'))
    approval_path = new_account_delegated_access_approval_path(service_provider_id: mybenefits.id)
    expect(rendered).to have_css("form[action='#{approval_path}'][method=get]")
    expect(rendered).not_to have_content(t('account.delegated_access.end_all'))
  end

  it 'shows a remembered approval with its time, time remaining and revoke links' do
    TokenExchangeGrant.approve!(
      user:, service_provider: mybenefits, application: housing,
      source: 'account_page', remember: true
    )
    @delegated_access = DelegatedAccessPresenter.new(user:)

    render

    expect(rendered).to have_css(
      '[data-delegated-access-application][data-status="approved"]',
      count: 1,
    )
    expect(rendered).to have_content(t('account.delegated_access.status_approved'))
    expect(rendered).to have_content(t('account.delegated_access.source_account_page'))
    expect(rendered).to have_link(
      t('account.delegated_access.revoke_application'),
      href: account_delegated_access_application_revocation_path(
        service_provider_id: mybenefits.id, application_id: housing.id,
      ),
    )
    expect(rendered).to have_link(
      t('account.delegated_access.revoke_service_provider', sp: 'MyBenefits Assistant'),
      href: account_delegated_access_service_provider_revocation_path(
        service_provider_id: mybenefits.id,
      ),
    )
    expect(rendered).to have_link(
      t('account.delegated_access.end_all'), href: account_delegated_access_revocation_path
    )
    expect(rendered).to have_css('details[open] [data-status="approved"]')
  end

  it 'explains when nothing is approved for delegation' do
    mybenefits.update!(token_exchange_enabled_sp: false)
    @delegated_access = DelegatedAccessPresenter.new(user:)

    render

    expect(rendered).to have_content(t('account.delegated_access.none_registered'))
  end
end
