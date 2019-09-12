require 'rails_helper'

describe 'phone configuration' do
  let(:user) { create(:user, :with_phone) }
  let(:phone_config2) do
    create(:phone_configuration, user: user,
                                 phone: '+1 202-555-2323',
                                 created_at: Time.zone.now + 1.hour)
  end

  describe 'sms delivery prefrence' do
    context 'when the user has not set a default phone number' do
      it 'uses the first phone created as the default' do
        sign_in_before_2fa(user)
        t('instructions.mfa.sms.number_message_html',
          number: '***-***-1212',
          expiration: Figaro.env.otp_valid_for)
      end
    end

    context 'when the user creates a new default phone number' do
      it 'displays the new default number for 2FA' do
        sign_in_visit_add_phone_path(user, phone_config2)

        enter_phone_number('202-555-3434')
        check 'user_phone_form_otp_make_default_number'
        click_button t('forms.buttons.continue')

        expect(page).to have_content t('instructions.mfa.sms.number_message_html',
                                       number: '+1 202-555-3434',
                                       expiration: Figaro.env.otp_valid_for)

        submit_prefilled_otp_code(user, 'sms')

        expect(page).to have_current_path(account_path)
        expect(page).to have_content t('account.index.default')

        sign_out_sign_in(user)
        expect(page).to have_content t('instructions.mfa.sms.number_message_html',
                                       number: '***-***-3434',
                                       expiration: Figaro.env.otp_valid_for)
      end
    end

    context 'when the user edits exiting phone and sets it as default' do
      it 'displays the new default number for 2FA with sms message' do
        new_phone = '202-555-3111'
        sign_in_visit_add_phone_path(user, phone_config2)
        fill_in :user_phone_form_phone, with: new_phone
        click_continue
        fill_in_code_with_last_phone_otp
        click_submit_default

        expect(page).to have_current_path(account_path)
        user.reload

        new_phone_config = nil
        user.phone_configurations.map { |phone_config|
          new_phone_config = phone_config if phone_config.phone.include? new_phone
        }
        sign_in_visit_manage_phone_path(user, new_phone_config)

        check 'user_phone_form_otp_make_default_number'
        click_button t('forms.buttons.submit.confirm_change')
        user.reload

        expect(page).to have_current_path(account_path)

        node = page.first('.account-list-item', text: new_phone)
        expect(node).to have_content '202-555-3111'
        parent = node.first(:xpath, './/..')
        expect(parent).to have_content t('account.index.default')

        sign_out_sign_in(user)
        expect(page).to have_content t('instructions.mfa.sms.number_message_html',
                                       number: '***-***-3111',
                                       expiration: Figaro.env.otp_valid_for)
      end
    end
  end

  describe 'voice delivery preference' do
    context 'when the user creates a new default phone number' do
      it 'displays the new default number for 2FA' do
        sign_in_visit_add_phone_path(user, phone_config2)

        enter_phone_number('202-555-3434')
        choose 'user_phone_form_otp_delivery_preference_voice'
        check 'user_phone_form_otp_make_default_number'
        click_button t('forms.buttons.continue')

        expect(page).to have_content t('instructions.mfa.voice.number_message_html',
                                       number: '+1 202-555-3434',
                                       expiration: Figaro.env.otp_valid_for)

        submit_prefilled_otp_code(user, 'voice')

        expect(page).to have_current_path(account_path)
        expect(page).to have_content t('account.index.default')

        sign_out_sign_in(user)
        expect(page).to have_content t('instructions.mfa.voice.number_message_html',
                                       number: '***-***-3434',
                                       expiration: Figaro.env.otp_valid_for)
      end
    end
  end

  def sign_out_sign_in(user)
    first(:link, t('links.sign_out')).click
    sign_in_before_2fa(user)
  end

  def submit_prefilled_otp_code(user, delivery_preference)
    expect(current_path).
      to eq login_two_factor_path(otp_delivery_preference: delivery_preference)
    fill_in('code', with: user.reload.direct_otp)
    click_button t('forms.buttons.submit.default')
  end

  def enter_phone_number(phone)
    fill_in 'user_phone_form[phone]', with: phone
  end

  def sign_in_visit_manage_phone_path(user, phone_config2)
    sign_in_and_2fa_user(user)
    visit manage_phone_path(id: phone_config2.id)
    expect(page).to have_content t('two_factor_authentication.otp_make_default_number.label')
  end

  def sign_in_visit_add_phone_path(user, phone_config2)
    sign_in_and_2fa_user(user)
    visit add_phone_path(id: phone_config2.id)
    expect(page).to have_content t('two_factor_authentication.otp_make_default_number.label')
  end
end
