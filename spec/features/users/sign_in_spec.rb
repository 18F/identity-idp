require 'rails_helper'

include SessionTimeoutWarningHelper
include ActionView::Helpers::DateHelper

feature 'Sign in' do
  scenario 'user cannot sign in if not registered' do
    signin('test@example.com', 'Please123!')
    expect(page).to have_content t('devise.failure.not_found_in_database')
  end

  scenario 'user cannot sign in with wrong email' do
    user = create(:user)
    signin('invalid@email.com', user.password)
    expect(page).to have_content t('devise.failure.not_found_in_database')
  end

  scenario 'user cannot sign in with empty email', js: true do
    signin('', 'foo')

    expect(page).to have_content 'Please fill in this field.'
  end

  scenario 'user cannot sign in with invalid email', js: true do
    signin('invalid', 'foo')

    expect(page).to have_content t('valid_email.validations.email.invalid')
  end

  scenario 'user cannot sign in with empty password', js: true do
    signin('test@example.com', '')

    expect(page).to have_content 'Please fill in this field.'
  end

  scenario 'user cannot sign in with wrong password' do
    user = create(:user)
    signin(user.email, 'invalidpass')
    expect(page).to have_content t('devise.failure.invalid')
  end

  scenario 'user can see and use password visibility toggle', js: true do
    visit new_user_session_path

    find('#pw-toggle-0', visible: false).trigger('click')

    expect(page).to have_css('input.password[type="text"]')
  end

  scenario 'user session expires in amount of time specified by Devise config' do
    sign_in_and_2fa_user

    visit profile_path
    expect(current_path).to eq profile_path

    Timecop.travel(Devise.timeout_in + 1.minute)

    visit profile_path
    expect(current_path).to eq root_path

    Timecop.return
  end

  context 'session approaches timeout', js: true do
    before :each do
      allow(Figaro.env).to receive(:session_check_frequency).and_return('1')
      allow(Figaro.env).to receive(:session_check_delay).and_return('2')
      allow(Figaro.env).to receive(:session_timeout_warning_seconds).
        and_return(Devise.timeout_in.to_s)
    end

    scenario 'user sees warning before session times out' do
      sign_in_and_2fa_user
      visit root_path

      expect(page).to have_css('#session-timeout-msg')

      request_headers = page.driver.network_traffic.flat_map(&:headers).uniq
      ajax_headers = { 'name' => 'X-Requested-With', 'value' => 'XMLHttpRequest' }

      expect(request_headers).to include ajax_headers
      expect(page).to have_content('7 minutes and 59 seconds')
      expect(page).to have_content('7 minutes and 58 seconds')

      find_link(t('forms.buttons.continue_browsing')).trigger('click')

      expect(current_path).to eq profile_path
    end
  end

  context 'signed out' do
    scenario 'displays session timeout modal when session times out', js: true do
      allow(Devise).to receive(:timeout_in).and_return(0)

      visit root_path

      expect(page).to have_css('#session-expired-msg')
    end

    scenario 'does not display timeout modal when session not timed out', js: true do
      allow(Devise).to receive(:timeout_in).and_return(60)

      visit root_path
      expect(page).not_to have_css('#session-expired-msg')
    end
  end

  context 'signing back in after session timeout length' do
    before do
      ActionController::Base.allow_forgery_protection = true
    end

    after do
      ActionController::Base.allow_forgery_protection = false
    end

    scenario 'fails to sign in the user, with CSRF error' do
      user = sign_in_and_2fa_user
      click_link(t('links.sign_out'))

      Timecop.travel(Devise.timeout_in + 1.minute) do
        expect(page).to_not have_content(t('forms.buttons.submit.continue'))

        fill_in_credentials_and_click_sign_in(user.email, user.password)

        expect(page).to have_content t('errors.invalid_authenticity_token')

        fill_in_credentials_and_click_sign_in(user.email, user.password)

        expect(current_path).to eq user_two_factor_authentication_path
      end
    end
  end

  context 'session timeout configuration' do
    scenario 'uses delay and warning settings whose sum is a multiple of 60' do
      expect((start + warning) % 60).to eq 0
    end

    scenario 'uses frequency and warning settings whose sum is a multiple of 60' do
      expect((frequency + warning) % 60).to eq 0
    end
  end

  context 'user attempts too many concurrent sessions' do
    scenario 'redirects to home page with error' do
      user = user_with_2fa

      Figaro.env.max_concurrent_sessions.to_i.times do |i|
        browser_name = "browser_#{i}".to_sym
        in_browser(browser_name) do
          visit new_user_session_path
          signin(user.email, user.password)
          expect(current_path).to eq user_two_factor_authentication_path
        end
      end

      in_browser(:over_limit) do
        visit new_user_session_path
        signin(user.email, user.password)

        expect(current_path).to eq new_user_session_path
        expect(page).to have_content(t('errors.messages.concurrent_sessions'))
      end
    end
  end

  def in_browser(name)
    old_session = Capybara.session_name
    Capybara.session_name = name
    yield
    Capybara.session_name = old_session
  end
end
