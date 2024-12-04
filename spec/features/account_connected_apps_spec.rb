require 'rails_helper'

RSpec.describe 'Account connected applications' do
  include NavigationHelper

  let(:user) do
    create(
      :user,
      :fully_registered,
      :with_multiple_emails,
      created_at: Time.zone.now - 100.days,
    )
  end
  let(:identity) do
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
  let(:identity_timestamp) do
    identity.created_at.utc.strftime(t('time.formats.event_timestamp'))
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

    expect(identity_without_link_timestamp).to appear_before(identity_timestamp)

    within_sidenav { click_on t('account.navigation.history') }
    expect(page).to have_content(
      t('event_types.authenticated_at', service_provider: identity_without_link.display_name),
    )
    expect(page).to_not have_link(identity_without_link.display_name)

    expect(page).to have_content(
      t(
        'event_types.authenticated_at_html',
        service_provider_link_html: identity.display_name,
      ),
    )
    expect(page).to have_link(
      identity.display_name, href: 'http://localhost:3000'
    )
  end

  scenario 'revoking consent from an SP' do
    within('li', text: identity.display_name) do
      click_link(t('account.revoke_consent.link_title'))
    end

    expect(page).to have_content(identity.display_name)

    # Canceling should return to the Connected Accounts page
    click_on t('links.cancel')
    expect(page).to have_current_path(account_connected_accounts_path)

    # Revoke again and confirm revocation
    within('li', text: identity.display_name) do
      click_link(t('account.revoke_consent.link_title'))
    end
    click_on t('forms.buttons.continue')

    # Accounts page should no longer list this app in the applications section
    expect(page).to_not have_content(identity.display_name)
  end

  scenario 'changing email shared with SP', :js do
    within('li', text: identity.display_name) do
      expect(page).to have_content(t('account.connected_apps.email_not_selected'))
      click_link(t('help_text.requested_attributes.change_email_link'))
    end

    click_on t('help_text.requested_attributes.select_email_link')

    input = page.find(':focus', visible: false)

    expect(input).to have_name(user.email)

    choose user.email_addresses.last.email
    click_on t('help_text.requested_attributes.select_email_link')

    within('li', text: identity.display_name) do
      expect(page).not_to have_content(t('account.connected_apps.email_not_selected'))
      expect(page).to have_content(user.email_addresses.last.email)
      click_link(t('help_text.requested_attributes.change_email_link'))
    end

    input2_id = "select_email_form_selected_email_id_#{user.email_addresses.last.id}"

    input2 = page.find(id: input2_id, visible: false)

    expect(input2).to have_name(user.email_addresses.last.email)

    choose user.email

    click_on(t('help_text.requested_attributes.select_email_link'))

    within('li', text: identity.display_name) do
      expect(page).to have_content(user.email)
    end

    expect(page).to have_content strip_tags(
      t('account.connected_apps.email_update_success_html', sp_name: identity.display_name),
    )
  end

  def build_account_connected_apps
    identity
    identity_without_link
  end
end
