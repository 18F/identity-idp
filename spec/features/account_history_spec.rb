require 'rails_helper'

describe 'Account history' do
  let(:user) { create(:user, :signed_up) }
  let(:account_created_event) { create(:event, user: user) }
  let(:identity_with_link) do
    create(
      :identity,
      :active,
      user: user,
      service_provider: 'http://localhost:3000'
    )
  end
  let(:identity_without_link) do
    create(
      :identity,
      :active,
      user: user,
      service_provider: 'https://rp2.serviceprovider.com/auth/saml/metadata'
    )
  end

  before do
    sign_in_and_2fa_user(user)
    build_account_history
    visit account_path
  end

  scenario 'viewing account history' do
    expect(page).to have_content(t('event_types.account_created'))

    expect(page).to have_content(
      t('event_types.authenticated_at', service_provider: identity_without_link.display_name)
    )
    expect(page).to_not have_link(identity_without_link.display_name)

    expect(page).to have_content(
      t('event_types.authenticated_at_html', service_provider_link: identity_with_link.display_name)
    )
    expect(page).to have_link(
      identity_with_link.display_name, href: 'http://localhost:3000'
    )
  end

  def build_account_history
    account_created_event
    identity_with_link
    identity_without_link
  end
end
