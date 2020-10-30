require 'rails_helper'

describe 'Add a new phone number' do
  scenario 'Adding and confirming a new phone number allows the phone number to be used for MFA' do
    user = create(:user, :signed_up)
    phone = '+1 (225) 278-1234'

    sign_in_and_2fa_user(user)
    click_on "+ #{t('account.index.phone_add')}"
    fill_in :new_phone_form_phone, with: phone
    click_continue
    fill_in_code_with_last_phone_otp
    click_submit_default

    expect(page).to have_current_path(account_path)
    expect(user.reload.phone_configurations.count).to eq(2)
    expect(user.phone_configurations[0].confirmed_at).to be_present
    expect(user.phone_configurations[1].confirmed_at).to be_present
  end

  scenario 'adding a new phone number sends the user an email with a disavowal link' do
    user = create(:user, :signed_up)
    phone = '+1 (225) 278-1234'

    expect(UserMailer).to receive(:phone_added).
      with(user, user.email_addresses.first, hash_including(:disavowal_token)).
      and_call_original

    sign_in_and_2fa_user(user)
    click_on "+ #{t('account.index.phone_add')}"
    fill_in :new_phone_form_phone, with: phone
    click_continue
    fill_in_code_with_last_phone_otp
    click_submit_default
  end

  scenario 'adding a phone that is already on the user account does not add another phone config' do
    user = create(:user, :signed_up)
    phone = user.phone_configurations.first.phone

    sign_in_and_2fa_user(user)
    click_on "+ #{t('account.index.phone_add')}"
    fill_in :new_phone_form_phone, with: phone
    click_continue
    fill_in_code_with_last_phone_otp
    click_submit_default

    expect(page).to have_current_path(account_path)
    expect(user.reload.phone_configurations.count).to eq(1)
  end

  context 'when the user does not have a phone' do
    scenario 'cancelling add phone otp confirmation redirect to account' do
      user = create(:user, :with_authentication_app)
      phone = '+1 (225) 278-1234'
      sign_in_and_2fa_user(user)
      click_on "+ #{t('account.index.phone_add')}"
      fill_in :new_phone_form_phone, with: phone
      click_continue
      click_link t('links.cancel')

      expect(page).to have_current_path(account_path)
      expect(user.reload.phone_configurations.count).to eq(0)
    end
  end
end
