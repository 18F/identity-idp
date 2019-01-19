require 'rails_helper'

describe 'Device Events' do
  let(:user) { create(:user, :signed_up) }
  before do
    user = create(:user, :signed_up, otp_delivery_preference: 'sms')
    sign_in_and_2fa_user(user)
    create(:device,
           user_id: user.id,
           cookie_uuid: 'foo',
           user_agent: 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_13_6) \
AppleWebKit/537.36 (KHTML, like Gecko) Chrome/71.0.3578.98 Safari/537.36',
           last_used_at: Time.zone.now,
           last_ip: '127.0.0.1')
    visit account_path
  end

  scenario 'viewing device events' do
    click_link t('headings.account.events')
    expect(page).to have_current_path(account_events_path(id: 1))
  end
end
