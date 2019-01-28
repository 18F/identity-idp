require 'rails_helper'

describe 'Device tracking' do
  let(:user) { create(:user, :signed_up) }

  before do
    create(:device, user_id: user.id, last_ip: '4.3.2.1', last_used_at: Time.zone.now)
    create(:event, device_id: device.id, ip: '4.3.2.1', user: user, created_at: Time.zone.now)
    sign_in_and_2fa_user(user)
  end

  context 'with account history' do
    it 'has account created events' do
      visit account_path
      expect(page).to have_content(t('event_types.account_created'))

      click_link t('headings.account.events')
      expect(page).to have_current_path(account_events_path(id: device.id))

      expect(page).to have_content(t('event_types.account_created'))
    end
  end
end
