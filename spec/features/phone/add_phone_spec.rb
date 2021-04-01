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

  scenario 'adding a new phone number validates number', js: true do
    user = create(:user, :signed_up)
    sign_in_and_2fa_user(user)
    click_on "+ #{t('account.index.phone_add')}"

    hidden_select = page.find('[name="new_phone_form[international_code]"]', visible: :hidden)

    find_button 'Continue', disabled: true
    expect(hidden_select.value).to eq('US')

    input = fill_in :new_phone_form_phone, with: '5135558410'
    expect(input.value).to eq('5135558410')
    find_button 'Continue', disabled: false
    expect(hidden_select.value).to eq('US')

    fill_in :new_phone_form_phone, with: 'abcd1234'
    find_button 'Continue', disabled: true
    expect(hidden_select.value).to eq('US')

    input = fill_in :new_phone_form_phone, with: '+81543543643'
    expect(input.value).to eq('+81 543543643')
    find_button 'Continue', disabled: false
    expect(hidden_select.value).to eq('JP')
  end

  scenario 'adding a phone that is already on the user account shows error message' do
    user = create(:user, :signed_up)
    phone = user.phone_configurations.first.phone

    sign_in_and_2fa_user(user)
    click_on "+ #{t('account.index.phone_add')}"
    fill_in :new_phone_form_phone, with: phone
    click_continue

    expect(page).to have_content(I18n.t('errors.messages.phone_duplicate'))
  end

  let(:telephony_gem_voip_number) { '+12255551000' }

  scenario 'adding a VOIP phone' do
    allow(FeatureManagement).to receive(:voip_block?).and_return(true)
    allow(FeatureManagement).to receive(:voip_check?).and_return(true)

    user = create(:user, :signed_up)

    sign_in_and_2fa_user(user)
    click_on "+ #{t('account.index.phone_add')}"
    fill_in :new_phone_form_phone, with: telephony_gem_voip_number
    click_continue
    expect(page).to have_content(t('errors.messages.voip_phone'))
  end

  scenario 'adding a phone in a different country', js: true do
    user = create(:user, :signed_up)

    sign_in_and_2fa_user(user)
    click_on "+ #{t('account.index.phone_add')}"

    expect(page.find('label', text: 'Text message (SMS)')).to_not match_css('.usa-button--disabled')
    expect(page.find('label', text: 'Phone call')).to_not match_css('.usa-button--disabled')

    page.find('div[aria-label="Country code"]').click
    within(page.find('.iti__flag-container')) do
      find('span', text: 'Australia').click # a country where SMS is disabled currently
    end

    expect(page.find('label', text: 'Text message (SMS)')).to_not match_css('.usa-button--disabled')
    expect(page.find('label', text: 'Phone call')).to match_css('.usa-button--disabled')
    expect(page.find('#otp_delivery_preference_instruction')).to have_content('Australia')
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
