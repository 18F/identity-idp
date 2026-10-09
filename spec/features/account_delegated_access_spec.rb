require 'rails_helper'

# Account > Delegated access: approving applications in advance (select, then confirm on a page
# with the consent-screen content), revoking one application, everything for a service provider,
# or everything; the account history and email that each action produces; and the way in from
# the connected services page.
RSpec.describe 'Account delegated access page', driver: :desktop_rack_test do
  let(:user) { create(:user, :fully_registered) }
  let!(:mybenefits) do
    create(:service_provider, :delegation_service_provider, friendly_name: 'MyBenefits Assistant')
  end
  let!(:housing) do
    create(
      :service_provider, :delegation_application,
      agency: create(:agency, name: 'Department of Housing Support'),
      delegation_display_name: { en: 'Housing Assistance Records' }
    )
  end
  let!(:retirement) do
    create(
      :service_provider, :delegation_application,
      agency: create(:agency, name: 'National Retirement Administration'),
      delegation_display_name: { en: 'Retirement Benefits Portal' }
    )
  end

  before do
    allow(IdentityConfig.store).to receive(:token_exchange_enabled).and_return(true)
    sign_in_and_2fa_user(user)
  end

  def live_grants
    TokenExchangeGrant.live.where(user:)
  end

  it 'approves selected applications after a confirmation page showing the agency content' do
    visit account_delegated_access_path

    expect(page).to have_content('MyBenefits Assistant')
    expect(page).to have_content('Department of Housing Support')
    # Agency groups without approvals start collapsed; the checkbox is still part of the form.
    find(
      :checkbox, "delegated_access_application_#{mybenefits.id}_#{housing.id}", visible: :all
    ).set(true)
    click_button t('account.delegated_access.approve_selected')

    expect(page).to have_current_path(
      new_account_delegated_access_approval_path(service_provider_id: mybenefits.id),
      ignore_query: true,
    )
    expect(page).to have_content(
      t('account.delegated_access.approve.heading', sp: 'MyBenefits Assistant'),
    )
    expect(page).to have_content('Housing Assistance Records')
    expect(page).not_to have_content('Retirement Benefits Portal')
    expect(live_grants).to be_empty

    click_button t('account.delegated_access.approve.confirm')

    expect(page).to have_current_path(account_delegated_access_path)
    expect(page).to have_content(
      t('account.delegated_access.approved_flash', count: 1, sp: 'MyBenefits Assistant'),
    )
    expect(live_grants.map(&:application)).to eq([housing])
    expect(live_grants.first.source).to eq('account_page')
    expect(user.events.where(event_type: 'delegation_approved').count).to eq(1)
    expect(last_email.subject).to eq(
      t('user_mailer.delegation_approved.subject', sp_name: 'MyBenefits Assistant'),
    )
  end

  it 'revokes one application, then everything for a service provider, then everything' do
    [housing, retirement].each do |application|
      TokenExchangeGrant.approve!(
        user:, service_provider: mybenefits, application:, source: 'account_page', remember: true,
      )
    end
    visit account_delegated_access_path

    within("[data-delegated-access-application][data-status='approved']", match: :first) do
      click_link t('account.delegated_access.revoke_application')
    end
    expect(page).to have_content(t('account.delegated_access.revoke.heading_application'))
    click_button t('account.delegated_access.revoke.confirm')
    expect(live_grants.count).to eq(1)
    expect(user.events.where(event_type: 'delegation_revoked').count).to eq(1)

    click_link t('account.delegated_access.revoke_service_provider', sp: 'MyBenefits Assistant')
    click_button t('account.delegated_access.revoke.confirm')
    expect(live_grants).to be_empty
    expect(page).not_to have_content(t('account.delegated_access.end_all'))

    TokenExchangeGrant.approve!(
      user:, service_provider: mybenefits, application: housing,
      source: 'account_page', remember: true
    )
    visit account_delegated_access_path
    click_link t('account.delegated_access.end_all')
    expect(page).to have_content(t('account.delegated_access.revoke.heading_all'))
    click_button t('account.delegated_access.revoke.confirm')
    expect(live_grants).to be_empty
    expect(last_email.subject).to eq(t('user_mailer.delegation_revoked.subject_all'))
  end

  it 'is reachable from the connected services page and the account navigation' do
    IdentityLinker.new(user, mybenefits).link_identity(verified_attributes: ['email'])

    visit account_connected_services_path
    click_link t('account.connected_apps.manage_delegated_access', sp: 'MyBenefits Assistant')
    expect(page).to have_current_path(account_delegated_access_path, ignore_query: true)
    expect(page).to have_link(t('account.navigation.delegated_access'))
  end

  it 'honors an advance approval on the consent screen and revokes it on disconnect' do
    TokenExchangeGrant.approve!(
      user:, service_provider: mybenefits, application: housing,
      source: 'account_page', remember: true
    )
    identity = IdentityLinker.new(user, mybenefits).link_identity(verified_attributes: ['email'])

    RevokeServiceProviderConsent.new(identity).call

    expect(live_grants).to be_empty
    expect(TokenExchangeGrant.where(user:).first.revocation_reason).to eq('sp_disconnected')
  end
end
