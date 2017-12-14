shared_examples 'idv otp delivery method selection' do |sp|
  let(:phone) { '555-123-4567' }

  before do
    visit_idp_from_sp_with_loa3(sp)
    register_user
    click_idv_begin
    fill_out_idv_form_ok
    click_idv_continue
    click_idv_address_choose_phone
    fill_out_phone_form_ok(phone)
    click_idv_continue
  end

  scenario 'selecting sms delivery method sends sems', :email do
    allow(SmsOtpSenderJob).to receive(:perform_later)
    choose_idv_otp_delivery_method_sms

    expect(SmsOtpSenderJob).to have_received(:perform_later)
    expect(current_path).to eq login_two_factor_path(otp_delivery_preference: :sms)
  end

  scenario 'selecting voice delivery method sends voice call', :email do
    allow(VoiceOtpSenderJob).to receive(:perform_later)
    choose_idv_otp_delivery_method_voice

    expect(VoiceOtpSenderJob).to have_received(:perform_later)
    expect(current_path).to eq login_two_factor_path(otp_delivery_preference: :voice)
  end

  scenario 'choosing to enter a different phone sends an OTP to that phone', :email do
    different_phone = '9876543210'

    choose_idv_otp_delivery_method_sms
    click_link t('forms.two_factor.try_again')

    expect(current_path).to eq verify_phone_path

    fill_out_phone_form_ok(different_phone)
    click_idv_continue

    allow(SmsOtpSenderJob).to receive(:perform_later)
    choose_idv_otp_delivery_method_sms

    expect(SmsOtpSenderJob).to have_received(:perform_later).
      with(hash_including(phone: different_phone))
  end

  context 'with a phone number that does not support voice calling' do
    let(:phone) { '671-555-5000' }

    scenario 'voice call option is disabled', :email do
      voice_radio_button = page.find(
        '#otp_delivery_selection_form_otp_delivery_preference_voice',
        visible: false
      )

      expect(voice_radio_button.disabled?).to eq(true)
      expect(page).to have_content t(
        'devise.two_factor_authentication.otp_delivery_preference.phone_unsupported',
        location: 'Guam'
      )
    end
  end
end
