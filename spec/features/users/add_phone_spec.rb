require 'rails_helper'

describe 'Add a new phone number' do
  scenario 'Adding and confirming a new phone number allows the phone number to be used for MFA' do
    user = create(:user, :signed_up)
    phone = '+1 (225) 278-1234'

    sign_in_and_2fa_user(user)
    click_on t('account.index.phone_add')
    fill_in :user_phone_form_phone, with: phone
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
      with(user.email_addresses.first, hash_including(:disavowal_token)).
      and_call_original

    sign_in_and_2fa_user(user)
    click_on t('account.index.phone_add')
    fill_in :user_phone_form_phone, with: phone
    click_continue
    fill_in_code_with_last_phone_otp
    click_submit_default
  end
end
