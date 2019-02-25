require 'rails_helper'

describe 'Device tracking' do
  let(:user) { create(:user, :signed_up) }
  let(:now) { Time.zone.now }
  let(:device) { create(:device, user: user, last_ip: '4.3.2.1', last_used_at: now) }

  before do
    create(:event, device: device, ip: '4.3.2.1', user: user, created_at: now)
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


  context 'when visiting the page for a device that does not exist' do
    it 'renders a 404 error' do
      visit account_events_path(id: 'dne')

      expect(page).to have_content(t('pages.page_not_found.header'))
    end
  end

  context 'when a user logs in from a new device' do
    it 'alerts the user their account is being used from a new device' do
      expect { sign_up_with(user.email) }.
          to change { ActionMailer::Base.deliveries.count }.by(1)

      expect(last_email.html_part.body).to have_content(
                                               t('user_mailer.signup_with_your_email.intro', app: APP_NAME),
                                               )
    end
  end
end
