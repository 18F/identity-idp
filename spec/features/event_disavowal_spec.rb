require 'rails_helper'

RSpec.feature 'disavowing an action' do
  let(:user) { create(:user, :fully_registered, :with_personal_key) }

  scenario 'disavowing a password reset' do
    perform_disavowable_password_reset
    disavow_last_action_and_reset_password
  end

  scenario 'disavowing a password update' do
    sign_in_and_2fa_user(user)
    visit manage_password_path
    password = 'OldVal!dPassw0rd'
    fill_in t('forms.passwords.edit.labels.password'), with: password
    fill_in t('components.password_confirmation.confirm_label'),
            with: password

    click_on t('forms.buttons.submit.update')
    Capybara.reset_sessions!

    disavow_last_action_and_reset_password
  end

  scenario 'disavowing a new device sign in' do
    allow(IdentityConfig.store).to receive(:otp_delivery_blocklist_maxretry).and_return(3)
    signin(user.email, user.password)
    Capybara.reset_session!
    visit root_path
    signin(user.email, user.password)

    disavow_last_action_and_reset_password
  end

  scenario 'disavowing a personal key sign in' do
    signin(user.email, user.password)
    choose_another_security_option(:personal_key)
    fill_in :personal_key_form_personal_key, with: user.personal_key
    click_submit_default

    disavow_last_action_and_reset_password
  end

  scenario 'disavowing a phone being added' do
    sign_in_and_2fa_user(user)
    visit phone_setup_path

    fill_in 'new_phone_form[phone]', with: '202-555-3434'

    choose 'new_phone_form_otp_delivery_preference_sms'
    check 'new_phone_form_otp_make_default_number'
    click_button t('forms.buttons.send_one_time_code')

    submit_prefilled_otp_code(user, 'sms')

    disavow_last_action_and_reset_password
  end

  scenario 'attempting to disavow an event with an invalid disavowal token' do
    visit event_disavowal_path(disavowal_token: 'this is a totally fake token')

    expect(page).to have_content(t('event_disavowals.errors.event_not_found'))
    expect(page).to have_current_path(root_path)
  end

  scenario 'returning after disavowing an action but not resetting password' do
    perform_disavowable_password_reset

    open_last_email

    # Click the disavowal link a first time
    click_email_link_matching(%r{events/disavow})
    expect(page).to have_content(t('headings.passwords.change'))

    # Click the disavowal link a second time and expect it to still work
    disavow_last_action_and_reset_password
  end

  scenario 'attempting to reset a password after having already disavowed an action' do
    disavow_link_regex = %r{/events/disavow\?disavowal_token=[^"]*}

    perform_disavowable_password_reset
    email = open_last_email
    disavowal_link = email.html.to_s.match(disavow_link_regex).to_s
    disavow_last_action_and_reset_password

    Capybara.reset_sessions!

    visit disavowal_link

    expect(page).to have_content(t('event_disavowals.errors.event_already_disavowed'))
    expect(page).to have_current_path(root_path)
  end

  scenario 'attempting to disavow an event after a long time and the disavowal has expired' do
    perform_disavowable_password_reset

    travel_to(11.days.from_now) do
      open_last_email
      click_email_link_matching(%r{events/disavow})

      expect(page).to have_content(t('event_disavowals.errors.event_disavowal_expired'))
      expect(page).to have_current_path(root_path)
    end
  end

  scenario 'disavowing an event and entering an invalid password' do
    perform_disavowable_password_reset

    open_last_email
    click_email_link_matching(%r{events/disavow})

    expect(page).to have_content(t('headings.passwords.change'))

    fill_in t('forms.passwords.edit.labels.password'), with: 'invalid'
    click_button t('forms.passwords.edit.buttons.submit')

    expect(page).to have_content t(
      'errors.attributes.password.too_short.other', count: Devise.password_length.first
    )

    fill_in t('forms.passwords.edit.labels.password'), with: 'NewVal!dPassw0rd'
    click_button t('forms.passwords.edit.buttons.submit')

    expect(page).to have_content(t('devise.passwords.updated_not_active'))

    signin(user.email, 'NewVal!dPassw0rd')

    # We should be on the MFA screen because we logged in with the new password
    expect(page).to have_content(t('two_factor_authentication.header_text'))
    expect(page.current_path).to eq(login_two_factor_path(otp_delivery_preference: :sms))
  end

  def submit_prefilled_otp_code(user, delivery_preference)
    expect(current_path).
      to eq login_two_factor_path(otp_delivery_preference: delivery_preference)
    fill_in('code', with: user.reload.direct_otp)
    click_button t('forms.buttons.submit.default')
  end

  def perform_disavowable_password_reset
    visit forgot_password_path
    fill_in :password_reset_email_form_email, with: user.email
    click_continue
    open_last_email
    click_email_link_matching(/reset_password_token/)
    password = 'OldVal!dPassw0rd'
    fill_in t('forms.passwords.edit.labels.password'), with: password
    fill_in t('components.password_confirmation.confirm_label'), with: password
    click_button t('forms.passwords.edit.buttons.submit')
  end

  def disavow_last_action_and_reset_password
    set_new_browser_session

    open_last_email
    click_email_link_matching(%r{events/disavow})

    expect(page).to have_content(t('headings.passwords.change'))

    fill_in t('forms.passwords.edit.labels.password'), with: 'NewVal!dPassw0rd'
    click_button t('forms.passwords.edit.buttons.submit')

    expect(page).to have_content(t('devise.passwords.updated_not_active'))

    signin(user.email, 'NewVal!dPassw0rd')

    # We should be on the MFA screen because we logged in with the new password
    expect(page).to have_content(t('two_factor_authentication.header_text'))
    expect(page.current_path).to eq(login_two_factor_path(otp_delivery_preference: :sms))
  end
end
