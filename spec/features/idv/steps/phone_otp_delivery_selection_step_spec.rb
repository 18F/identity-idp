require 'rails_helper'

feature 'IdV phone OTP deleivery method selection', :idv_job do
  include IdvStepHelper

  context 'the users chooses sms' do
    it 'sends an sms and redirects to otp verification' do
      expect(VoiceOtpSenderJob).to_not receive(:perform_later)
      expect(SmsOtpSenderJob).to receive(:perform_later)

      start_idv_from_sp
      complete_idv_steps_before_phone_otp_delivery_selection_step
      choose_idv_otp_delivery_method_sms

      expect(page).to have_content(t('devise.two_factor_authentication.header_text'))
      expect(current_path).to eq(login_two_factor_path(otp_delivery_preference: :sms))
    end
  end

  context 'the user chooses voice' do
    it 'sends a voice call and redirects to otp verification' do
      expect(VoiceOtpSenderJob).to receive(:perform_later)
      expect(SmsOtpSenderJob).to_not receive(:perform_later)

      start_idv_from_sp
      complete_idv_steps_before_phone_otp_delivery_selection_step
      choose_idv_otp_delivery_method_voice

      expect(page).to have_content(t('devise.two_factor_authentication.header_text'))
      expect(current_path).to eq(login_two_factor_path(otp_delivery_preference: :voice))
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
      expect(VoiceOtpSenderJob).to_not receive(:perform_later)
      expect(SmsOtpSenderJob).to_not receive(:perform_later)
      expect(page).to have_content(t('errors.messages.must_have_us_country_code'))
      expect(current_path).to eq(idv_phone_path)
    end
  end

  context 'cancelling IdV' do
    it_behaves_like 'cancel at idv step', :phone_otp_delivery_selection
    it_behaves_like 'cancel at idv step', :phone_otp_delivery_selection, :oidc
    it_behaves_like 'cancel at idv step', :phone_otp_delivery_selection, :saml
  end
end
