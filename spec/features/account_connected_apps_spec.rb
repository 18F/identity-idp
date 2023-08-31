require 'rails_helper'

RSpec.describe 'Account connected applications' do
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
    visit account_connected_accounts_path
  end

  scenario 'viewing account connected applications' do
    expect(page).to have_content(t('headings.account.connected_accounts'))

    visit account_history_path
    expect(page).to have_content( \
      t('event_types.authenticated_at', service_provider: identity_without_link.display_name),
    )
    expect(page).to_not have_link(identity_without_link.display_name)

    expect(page).to have_content( \
      t(
        'event_types.authenticated_at_html',
        service_provider_link: identity_with_link.display_name,
      ),
    )
    expect(page).to have_link( \
      identity_with_link.display_name, href: 'http://localhost:3000'
    )

    visit account_connected_accounts_path
    expect(identity_without_link_timestamp).to appear_before(identity_with_link_timestamp)
  end

  scenario 'revoking consent from an SP' do
    identity_to_revoke = identity_with_link

    visit account_history_path
    expect(page).to have_content(
      t('event_types.authenticated_at', service_provider: identity_to_revoke.display_name),
    )

    visit account_connected_accounts_path
    within(find('.profile-info-box')) do
      within(find('.grid-row', text: identity_to_revoke.service_provider_record.friendly_name)) do
        click_link(t('account.revoke_consent.link_title'))
      end
    end

    expect(page).to have_content(identity_to_revoke.service_provider_record.friendly_name)
    click_on t('forms.buttons.continue')

    # Accounts page should no longer list this app in the applications section
    expect(page).to_not have_content(identity_to_revoke.service_provider_record.friendly_name)
  end

  def build_account_connected_apps
    identity_with_link
    identity_without_link
  end
end
