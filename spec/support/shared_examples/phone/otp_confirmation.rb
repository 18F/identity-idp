shared_examples 'phone otp confirmation' do |delivery_method|
  it 'allows the user to confirm a phone' do
    visit_otp_confirmation(delivery_method)
    fill_in :code, with: last_otp(delivery_method)
    click_submit_default
    click_continue
    expect_successful_otp_confirmation(delivery_method)
  end

  it 'renders an error if the user enters an incorrect otp' do
    visit_otp_confirmation(delivery_method)
    fill_in :code, with: '123456'
    click_submit_default
    expect(page).to have_content(t('two_factor_authentication.invalid_otp'))
    expect_failed_otp_confirmation(delivery_method)
  end

  it 'renders an error if the user does not enter an otp' do
    visit_otp_confirmation(delivery_method)
    fill_in :code, with: ''
    click_submit_default
    expect(page).to have_content(t('two_factor_authentication.invalid_otp'))
    expect_failed_otp_confirmation(delivery_method)
  end

  it 'renders an error if the OTP has expired' do
    visit_otp_confirmation(delivery_method)
    travel_to(11.minutes.from_now) do
      fill_in :code, with: last_otp(delivery_method)
      click_submit_default
      expect(page).to have_content(t('two_factor_authentication.invalid_otp'))
      expect_failed_otp_confirmation(delivery_method)
    end
  end

  it 'allows the user to resend an OTP and confirm with the new OTP' do
    visit_otp_confirmation(delivery_method)
    old_code = last_otp(delivery_method)
    click_on t('links.two_factor_authentication.send_another_code')
    new_code = last_otp(delivery_method)

    expect(old_code).to_not eq(new_code)

    fill_in :code, with: new_code
    click_submit_default
    click_continue

    expect_successful_otp_confirmation(delivery_method)
  end

  def last_otp(delivery_method)
    if delivery_method == :voice
      last_voice_otp(phone: formatted_phone)
    elsif delivery_method == :sms
      last_sms_otp(phone: formatted_phone)
    end
  end
end
