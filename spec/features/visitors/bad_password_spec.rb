require 'rails_helper'

RSpec.feature 'Visitor signs in with bad passwords and gets locked out' do
  include ActionView::Helpers::DateHelper
  let(:user) { create(:user, :fully_registered) }
  let(:bad_password) { 'badpassword' }
  let(:window) { IdentityConfig.store.max_bad_passwords_window_in_seconds.seconds }

  scenario 'visitor tries too many bad passwords gets locked out then waits window seconds' do
    visit new_user_session_path
    error_message = t(
      'devise.failure.invalid_html',
      link_html: t('devise.failure.invalid_link_text'),
    )
    IdentityConfig.store.max_bad_passwords.times do
      fill_in_credentials_and_submit(user.email, bad_password)
      expect(page).to have_content(error_message)
      expect(page).to have_current_path(new_user_session_path)
    end
    locked_at = Time.zone.at(page.get_rack_session['max_bad_passwords_at'])
    # Need to do this because getting rack session changes the url.
    visit new_user_session_path
    2.times do
      freeze_time do 
        fill_in_credentials_and_submit(user.email, bad_password)

        expect(page).to have_current_path(new_user_session_path)
        new_time = Time.zone.at(locked_at) + window
        time_left = distance_of_time_in_words(Time.zone.now, new_time, true)
        expect(page).to have_content(
          t(
            'errors.sign_in.bad_password_limit',
            time_left: time_left,
          ),
        )
      end
    end
    freeze_time do 
      fill_in_credentials_and_submit(user.email, user.password)
    
      expect(page).to have_current_path(new_user_session_path)
      new_time = Time.zone.at(locked_at) + window
      time_left = distance_of_time_in_words(Time.zone.now, new_time, true)
      expect(page).to have_content(
        t(
          'errors.sign_in.bad_password_limit',
          time_left: time_left,
        ),
      )
    end

    travel_to(IdentityConfig.store.max_bad_passwords_window_in_seconds.seconds.from_now) do
      fill_in_credentials_and_submit(user.email, bad_password)
      expect(page).to have_content(error_message)
      fill_in_credentials_and_submit(user.email, user.password)
      expect(page).to have_current_path(login_two_factor_path(otp_delivery_preference: 'sms'))
    end
  end
end
