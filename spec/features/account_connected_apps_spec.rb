require 'rails_helper'

RSpec.describe 'Account connected applications' do
  include NavigationHelper

  let(:user) { create(:user, :fully_registered, created_at: Time.zone.now - 100.days) }
  let(:identity_with_link) do
    create(
      :service_provider_identity,
      :active,
      user: user,
      created_at: Time.zone.now - 80.days,
      service_provider: 'http://localhost:3000',
    )
  end
  let(:identity_without_link) do
    create(
      :service_provider_identity,
      :active,
      user: user,
      created_at: Time.zone.now - 50.days,
      service_provider: 'https://rp2.serviceprovider.com/auth/saml/metadata',
    )
  end
  let(:identity_with_link_timestamp) do
    identity_with_link.created_at.utc.strftime(t('time.formats.event_timestamp'))
  end
  let(:identity_without_link_timestamp) do
    identity_without_link.created_at.utc.strftime(t('time.formats.event_timestamp'))
  end

  before do
    sign_in_and_2fa_user(user)
    build_account_connected_apps
    within_sidenav { click_on t('account.navigation.connected_accounts') }
  end

  scenario 'viewing account connected applications' do
    expect(page).to have_content(t('headings.account.connected_accounts'))

    expect(identity_without_link_timestamp).to appear_before(identity_with_link_timestamp)

    within_sidenav { click_on t('account.navigation.history') }
    expect(page).to have_content(
      t('event_types.authenticated_at', service_provider: identity_without_link.display_name),
    )
    expect(page).to_not have_link(identity_without_link.display_name)

    expect(page).to have_content(
      t(
        'event_types.authenticated_at_html',
        service_provider_link_html: identity_with_link.display_name,
      ),
    )
    expect(page).to have_link(
      identity_with_link.display_name, href: 'http://localhost:3000'
    )
  end

  scenario 'revoking consent from an SP' do
    identity_to_revoke = identity_with_link

    within('li', text: identity_to_revoke.display_name) do
      click_link(t('account.revoke_consent.link_title'))
    end

    expect(page).to have_content(identity_to_revoke.display_name)

    # Canceling should return to the Connected Accounts page
    click_on t('links.cancel')
    expect(page).to have_current_path(account_connected_accounts_path)

    # Revoke again and confirm revocation
    within('li', text: identity_to_revoke.display_name) do
      click_link(t('account.revoke_consent.link_title'))
    end
    click_on t('forms.buttons.continue')

    # Accounts page should no longer list this app in the applications section
    expect(page).to_not have_content(identity_to_revoke.display_name)
  end

  def build_account_connected_apps
    identity_with_link
    identity_without_link
  end
end
