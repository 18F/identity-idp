require 'rails_helper'

describe 'Add a new phone number' do
  scenario 'Adding and confirming a new phone number allows the phone number to be used for MFA' do
    user = create(:user, :signed_up)
    phone = '+1 (225) 278-1234'

    sign_in_and_2fa_user(user)
    expect(page).to have_link(t('account.index.phone_add'), normalize_ws: true, exact: true)
    within('.sidenav') do
      click_on t('account.navigation.add_phone_number')
    end
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

    sign_in_and_2fa_user(user)
    within('.sidenav') do
      click_on t('account.navigation.add_phone_number')
    end
    fill_in :new_phone_form_phone, with: phone
    click_continue
    fill_in_code_with_last_phone_otp
    click_submit_default

    expect_delivered_email_count(1)
    expect_delivered_email(
      to: [user.email_addresses.first.email],
      subject: t('user_mailer.phone_added.subject'),
    )
  end

  scenario 'adding a new phone number validates number', js: true do
    user = create(:user, :signed_up)
    sign_in_and_2fa_user(user)
    within('.sidenav') do
      click_on t('account.navigation.add_phone_number')
    end

    hidden_select = page.find('[name="new_phone_form[international_code]"]', visible: :hidden)

    # Required field should prompt as required on submit
    click_continue
    focused_input = page.find(':focus')
    expect(focused_input).to match_css('.phone-input__number.usa-input--error')
    expect(hidden_select.value).to eq('US')

    error_message_id = focused_input[:'aria-describedby']&.split(' ')&.find do |id|
      page.has_css?(".usa-error-message##{id}")
    end
    expect(error_message_id).to_not be_empty

    error_message = page.find_by_id(error_message_id)
    expect(error_message).to have_content(t('errors.messages.phone_required'))

    # Invalid number should prompt as invalid on submit
    fill_in :new_phone_form_phone, with: 'abcd1234'
    click_continue
    focused_input = page.find(':focus')
    expect(focused_input).to match_css('.phone-input__number.usa-input--error')
    expect(hidden_select.value).to eq('US')

    error_message_id = focused_input[:'aria-describedby']&.split(' ')&.find do |id|
      page.has_css?(".usa-error-message##{id}")
    end
    expect(error_message_id).to_not be_empty

    error_message = page.find_by_id(error_message_id)
    expect(error_message).to have_content(t('errors.messages.invalid_phone_number'))

    # Unsupported country should prompt as invalid and hide delivery options immediately
    page.find('div[aria-label="Country code"]').click
    within(page.find('.iti__flag-container', visible: :all)) do
      find('span', text: 'Sri Lanka').click
    end
    focused_input = page.find('.phone-input__number:focus')

    error_message_id = focused_input[:'aria-describedby']&.split(' ')&.find do |id|
      page.has_css?(".usa-error-message##{id}")
    end
    expect(error_message_id).to_not be_empty

    error_message = page.find_by_id(error_message_id)
    expect(error_message).to have_content(
      t(
        'two_factor_authentication.otp_delivery_preference.no_supported_options',
        location: 'Sri Lanka',
      ),
    )

    expect(page).to_not have_content(t('two_factor_authentication.otp_delivery_preference.title'))
    expect(hidden_select.value).to eq('LK')
    fill_in :new_phone_form_phone, with: '+94 071 234 5678'
    click_continue
    expect(page.find(':focus')).to match_css('.phone-input__number')

    # Switching to supported country should re-show delivery options, but prompt as invalid number
    page.find('div[aria-label="Country code"]').click
    within(page.find('.iti__flag-container', visible: :all)) do
      find('span', text: 'United States').click
    end
    expect(page).to have_content(t('two_factor_authentication.otp_delivery_preference.title'))
    expect(page).to_not have_css('.usa-error-message')
    expect(hidden_select.value).to eq('US')
    click_continue
    expect(page.find(':focus')).to match_css('.phone-input__number')
    expect(page).to have_content(t('errors.messages.invalid_phone_number'))

    # Entering valid number should allow submission
    input = fill_in :new_phone_form_phone, with: '+81543543643'
    expect(input.value).to eq('+81 543543643')
    expect(hidden_select.value).to eq('JP')
    click_continue
    expect(page).to have_content(t('components.one_time_code_input.label'))
  end

  scenario 'Displays an error message when max phone numbers are reached' do
    allow(IdentityConfig.store).to receive(:max_phone_numbers_per_account).and_return(1)
    user = create(:user, :signed_up)
    sign_in_and_2fa_user(user)
    expect(page).to_not have_link(t('account.index.phone_add'), normalize_ws: true, exact: true)
    within('.sidenav') do
      click_on t('account.navigation.add_phone_number')
    end
    expect(page).to have_css(
      '#phones.usa-alert.usa-alert--error',
      text: t('users.phones.error_message'),
    )
  end

  scenario 'adding a phone that is already on the user account shows error message' do
    user = create(:user, :signed_up)
    phone = user.phone_configurations.first.phone

    sign_in_and_2fa_user(user)
    within('.sidenav') do
      click_on t('account.navigation.add_phone_number')
    end
    fill_in :new_phone_form_phone, with: phone
    click_continue

    expect(page).to have_content(I18n.t('errors.messages.phone_duplicate'))
  end

  let(:telephony_gem_voip_number) { '+12255551000' }

  scenario 'adding a VOIP phone' do
    allow(IdentityConfig.store).to receive(:voip_block).and_return(true)
    allow(IdentityConfig.store).to receive(:voip_check).and_return(true)

    user = create(:user, :signed_up)

    sign_in_and_2fa_user(user)
    within('.sidenav') do
      click_on t('account.navigation.add_phone_number')
    end
    fill_in :new_phone_form_phone, with: telephony_gem_voip_number
    click_continue
    expect(page).to have_content(t('errors.messages.voip_check_error'))
  end

  scenario 'adding a phone in a different country', js: true do
    user = create(:user, :signed_up)

    sign_in_and_2fa_user(user)
    within('.sidenav') do
      click_on t('account.navigation.add_phone_number')
    end

    expect(page.find_field('Text message (SMS)', disabled: false, visible: :all)).to be_present
    expect(page.find_field('Phone call', disabled: false, visible: :all)).to be_present

    page.find('div[aria-label="Country code"]').click
    within(page.find('.iti__flag-container', visible: :all)) do
      find('span', text: 'Australia').click # a country where SMS is disabled currently
    end

    expect(page.find_field('Text message (SMS)', disabled: false, visible: :all)).to be_present
    expect(page.find_field('Phone call', disabled: true, visible: :all)).to be_present
    expect(page.find('#otp_delivery_preference_instruction')).to have_content('Australia')
  end

  context 'when the user does not have a phone' do
    scenario 'cancelling add phone otp confirmation redirect to account' do
      user = create(:user, :with_authentication_app)
      phone = '+1 (225) 278-1234'
      sign_in_and_2fa_user(user)
      within('.sidenav') do
        click_on t('account.navigation.add_phone_number')
      end
      fill_in :new_phone_form_phone, with: phone
      click_continue
      click_link t('links.cancel')

      expect(page).to have_current_path(account_path)
      expect(user.reload.phone_configurations.count).to eq(0)
    end
  end
end
