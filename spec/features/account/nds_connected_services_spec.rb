require 'rails_helper'

RSpec.feature 'NDS connected services' do
  let(:user) { create(:user, :fully_registered, :with_multiple_emails) }
  let!(:identity) do
    create(
      :service_provider_identity,
      :active,
      user:,
      service_provider: 'http://localhost:3000',
      verified_attributes: %w[email],
    )
  end

  before do
    allow(IdentityConfig.store).to receive(:ui_test_bucket_params_enabled).and_return(true)
    sign_in_and_2fa_user(user)
    visit account_connected_services_path(ui_test_bucket: 'nds')
  end

  def agency_row
    find('.connected-services li.discovery-service', text: identity.display_name)
  end

  def open_agency_menu
    agency_row.find('details.connected-service__menu > summary').click
  end

  scenario 'the connected agencies render in the account shell' do
    expect(page).to have_css(
      '.account-shell main h1',
      text: t('headings.account.connected_services'),
    )
    expect(page).to have_css(
      '.account-shell__nav .account-nav__link--current',
      text: t('nds.account_nav.home'),
    )
    expect(agency_row).to have_content(t('account.connected_apps.email_not_selected'))
  end

  scenario 'changing the email shared with an agency from the row menu' do
    open_agency_menu
    within(agency_row) { click_link t('nds.dashboard_home.manage_preferences') }

    expect(page).to have_current_path(
      edit_connected_service_selected_email_path(identity_id: identity.id),
    )
    expect(page).to have_css('header.account-header')
    expect(page).to have_css('h1', text: identity.display_name)

    new_email = user.email_addresses.last.email
    find('label', text: new_email).click
    click_button t('components.manageable_authenticator.save')

    expect(page).to have_current_path(account_connected_services_path)
    expect(page).to have_css(
      '.usa-alert--success',
      text: strip_tags(
        t('account.connected_apps.email_update_success_html', sp_name: identity.display_name),
      ),
    )
    expect(agency_row).to have_content(new_email)
    expect(identity.reload.email_address.email).to eq(new_email)
  end

  scenario 'canceling the email change returns to the connected agencies' do
    open_agency_menu
    within(agency_row) { click_link t('nds.dashboard_home.manage_preferences') }
    click_link t('links.cancel')

    expect(page).to have_current_path(account_connected_services_path)
    expect(identity.reload.email_address_id).to be_nil
  end

  scenario 'disconnecting an agency from the row menu' do
    open_agency_menu
    within(agency_row) { click_link t('account.revoke_consent.link_title') }

    expect(page).to have_css(
      'h1',
      text: t('nds.dashboard_home.revoke_heading', sp_name: identity.display_name),
    )
    click_link t('links.cancel')
    expect(page).to have_current_path(account_connected_services_path)
    expect(page).to have_css('li.discovery-service', text: identity.display_name)

    open_agency_menu
    within(agency_row) { click_link t('account.revoke_consent.link_title') }
    click_button t('account.revoke_consent.link_title')

    expect(page).to have_current_path(account_connected_services_path)
    expect(page).not_to have_css('li.discovery-service', text: identity.display_name)
  end

  context 'with an America.gov consent' do
    let!(:consent) { create(:user_consent_sts, user:, created_at: 10.days.ago) }
    let(:delegation_section) do
      find(
        'section',
        text: t('account.navigation.america_gov_services', america_gov_name: AMERICA_GOV_NAME),
      )
    end

    before do
      allow(IdentityConfig.store).to receive(:sts_consent_expiration_in_days).and_return(365)
      visit account_connected_services_path
    end

    scenario 'disconnecting the America.gov consent' do
      within(delegation_section) { click_link t('forms.buttons.edit') }

      expect(page).to have_css('h1', text: 'MyTravelGov')
      click_link t('links.cancel')
      expect(page).to have_current_path(account_connected_services_path)
      expect(user.reload.connected_delegations.count).to eq(1)

      within(delegation_section) { click_link t('forms.buttons.edit') }
      click_button t('account.revoke_consent.link_title')

      expect(page).to have_current_path(account_connected_services_path)
      expect(page).not_to have_content(
        t('account.navigation.america_gov_services', america_gov_name: AMERICA_GOV_NAME),
      )
      expect(user.reload.connected_delegations.count).to eq(0)
    end
  end
end
