require 'rails_helper'

RSpec.describe 'Account connected delegations' do
  let(:user) { create(:user, :fully_registered) }
  let(:delegation_heading) do
    t('account.navigation.america_gov_services', america_gov_name: AMERICA_GOV_NAME)
  end

  before do
    allow(IdentityConfig.store).to receive(:sts_consent_expiration_in_days).and_return(365)
    sign_in_and_2fa_user(user)
  end

  context 'without an STS consent' do
    scenario 'the delegation section is hidden' do
      visit account_connected_services_path

      expect(page).to have_content(t('headings.account.connected_services'))
      expect(page).to_not have_content(delegation_heading)
    end
  end

  context 'with an STS consent' do
    let!(:consent) { create(:user_consent_sts, user:, created_at: 10.days.ago) }

    before { visit account_connected_services_path }

    scenario 'the delegation section lists the consent with its connection date' do
      expect(page).to have_content(delegation_heading)
      expect(page).to have_content(
        consent.created_at.utc.strftime(t('time.formats.event_timestamp')),
      )
    end

    scenario 'disconnecting removes the consent' do
      within('li', text: 'MyTravelGov') do
        click_link(t('account.revoke_consent.link_title'))
      end

      # Canceling should return to the connected services page
      click_on t('links.cancel')
      expect(page).to have_current_path(account_connected_services_path)
      expect(user.reload.connected_delegations.count).to eq(1)

      within('li', text: 'MyTravelGov') do
        click_link(t('account.revoke_consent.link_title'))
      end
      click_on t('forms.buttons.continue')

      expect(page).to have_current_path(account_connected_services_path)
      expect(page).to_not have_content(delegation_heading)
      expect(user.reload.connected_delegations.count).to eq(0)
    end
  end
end
