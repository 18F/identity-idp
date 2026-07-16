require 'rails_helper'

RSpec.describe 'Devices' do
  let(:user) { create(:user, :fully_registered, otp_delivery_preference: 'sms') }
  let!(:device) do
    create(
      :device,
      user: user,
      cookie_uuid: 'foo',
      user_agent: 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_13_6) ' \
                  'AppleWebKit/537.36 (KHTML, like Gecko) Chrome/71.0.3578.98 Safari/537.36',
      last_used_at: Time.zone.now,
      last_ip: '127.0.0.1',
    )
  end

  before do
    sign_in_and_2fa_user(user)
    visit account_history_path
  end

  scenario 'viewing devices' do
    expect(page).to have_content('Chrome 71 on macOS')
  end

  scenario 'drilling into a device renders inside the account shell with History current' do
    click_on t('account.dashboard.history.details')

    expect(page).to have_current_path(account_events_path(id: device.id))
    expect(page).to have_css('.ads-account-shell')
    expect(page).to have_css('h1', text: 'Chrome 71 on macOS')

    within('.ads-account-shell__nav') do
      expect(page).to have_css(
        '.ads-account-nav__link--current',
        text: t('account.navigation.history'),
      )
    end
  end

  scenario 'the drill-in back button returns to history' do
    click_on t('account.dashboard.history.details')
    click_on t('account.dashboard.history.back_to_history')

    expect(page).to have_current_path(account_history_path)
  end
end
