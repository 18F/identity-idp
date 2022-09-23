require 'rails_helper'

feature 'IdV phone OTP delivery method selection', :js do
  include IdvStepHelper

  context 'the users chooses sms' do
    it 'sends an sms and redirects to otp verification' do
      expect(Telephony).to receive(:send_confirmation_otp).
        with(hash_including(channel: :sms)).
        and_call_original

      start_idv_from_sp
      complete_idv_steps_before_phone_otp_delivery_selection_step
      choose_idv_otp_delivery_method_sms

      expect(page).to have_content(t('two_factor_authentication.header_text'))
      expect(current_path).to eq(idv_otp_verification_path)
    end
  end

  context 'the user chooses voice' do
    it 'sends a voice call and redirects to otp verification' do
      expect(Telephony).to receive(:send_confirmation_otp).
        with(hash_including(channel: :voice)).
        and_call_original

      start_idv_from_sp
      complete_idv_steps_before_phone_otp_delivery_selection_step
      choose_idv_otp_delivery_method_voice

      expect(page).to have_content(t('two_factor_authentication.header_text'))
      expect(current_path).to eq(idv_otp_verification_path)
    end
  end

  context 'the user does not make a selection' do
    it 'does not send a voice call or sms and renders an error' do
      expect(Telephony).to_not receive(:send_confirmation_otp)

      start_idv_from_sp
      complete_idv_steps_before_phone_otp_delivery_selection_step
      click_on t('idv.buttons.send_confirmation_code')

      expect(page).to have_content(t('idv.errors.unsupported_otp_delivery_method'))
      expect(current_path).to eq(idv_otp_delivery_method_path)
    end
  end

  context 'the user opts to verify by mail instead' do
    it 'can return back to the OTP selection screen' do
      start_idv_from_sp
      complete_idv_steps_before_phone_otp_delivery_selection_step
      click_on t('idv.troubleshooting.options.verify_by_mail')

      expect(page).to have_content(t('idv.titles.mail.verify'))

      click_doc_auth_back_link
      expect(current_path).to eq(idv_otp_delivery_method_path)
    end
  end

  context 'with a non-US number' do
    let(:bahamas_phone) { '+12423270143' }

    before do
      start_idv_from_sp
      complete_idv_steps_before_phone_step
      fill_out_phone_form_ok(bahamas_phone)
      click_idv_continue
    end

    it 'displays an error message' do
      expect(Telephony).to_not receive(:send_confirmation_otp)
      expect(page).to have_content(t('errors.messages.invalid_phone_number'))
      expect(current_path).to eq(idv_phone_path)
    end
  end

  it 'does not modify the otp column on the user model when sending an OTP' do
    user = user_with_2fa

    start_idv_from_sp
    complete_idv_steps_before_phone_otp_delivery_selection_step(user)

    old_direct_otp = user.direct_otp
    choose_idv_otp_delivery_method_sms
    user.reload

    expect(user.direct_otp).to eq(old_direct_otp)
  end

  it 'redirects back to the step with an error if the telephony gem raises an error' do
    user = user_with_2fa

    start_idv_from_sp
    complete_idv_steps_before_phone_step(user)
    fill_out_phone_form_ok('2255551000')
    click_idv_continue

    choose_idv_otp_delivery_method_sms

    expect(page).to have_content(I18n.t('telephony.error.friendly_message.generic'))
    expect(page).to have_current_path(idv_phone_path)

    fill_out_phone_form_ok('2255552000')
    click_idv_continue

    choose_idv_otp_delivery_method_sms

    expect(page).to have_content(I18n.t('telephony.error.friendly_message.invalid_calling_area'))
    expect(page).to have_current_path(idv_phone_path)
  end
end
