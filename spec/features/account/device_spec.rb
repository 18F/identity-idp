require 'rails_helper'

describe 'Devices' do
  let(:user) { create(:user, :signed_up) }
  before do
    user = create(:user, :signed_up, otp_delivery_preference: 'sms')
    sign_in_and_2fa_user(user)
    create(
      :device,
      user: user,
      cookie_uuid: 'foo',
      user_agent: 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_13_6) \
AppleWebKit/537.36 (KHTML, like Gecko) Chrome/71.0.3578.98 Safari/537.36',
      last_used_at: Time.zone.now,
      last_ip: '127.0.0.1',
    )
    visit account_history_path
  end

  scenario 'viewing devices' do
    expect(page).to have_content('Chrome 71 on macOS 10')
  end
end
