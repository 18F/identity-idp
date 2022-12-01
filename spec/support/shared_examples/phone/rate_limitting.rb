shared_examples 'phone rate limitting' do |delivery_method|
  let(:max_confirmation_attempts) { 2 }
  let(:max_otp_sends) { 2 }

  before do
    allow(IdentityConfig.store).to receive(:login_otp_confirmation_max_attempts).
      and_return(max_confirmation_attempts)
    allow(IdentityConfig.store).to receive(:otp_delivery_blocklist_maxretry).
      and_return(max_otp_sends)
  end

  it 'limits the number of times the user can resend an OTP' do
    visit_otp_confirmation(delivery_method)
    max_otp_sends.times do
      click_on t('links.two_factor_authentication.send_another_code')
    end

    expect(page).to have_content(t('two_factor_authentication.max_otp_requests_reached'))
    expect_user_to_be_rate_limitted
    expect_rate_limitting_to_expire
  end

  it 'limits the number of times a code can be sent to a phone across accounts' do
    visit_otp_confirmation(delivery_method)
    max_otp_sends.times do
      click_on t('links.two_factor_authentication.send_another_code')
    end

    Capybara.reset_session!

    visit root_path
    sign_up_and_set_password
    select_2fa_option(:phone)
    fill_in :new_phone_form_phone, with: phone
    click_send_one_time_code

    expect(page).to have_content(t('two_factor_authentication.max_otp_requests_reached'))

    expect_user_to_be_rate_limitted
    expect_rate_limitting_to_expire
  end

  it 'limits the number of times the user can enter an OTP' do
    visit_otp_confirmation(delivery_method)
    (max_confirmation_attempts - 1).times do |number_of_times|
      fill_in :code, with: '123456'
      click_submit_default
      current_count = max_confirmation_attempts - number_of_times
      expect(page).to have_content(
        t(
          'two_factor_authentication.invalid_otp',
          count: current_count,
        ),
      )
      expect(current_path).to eq login_two_factor_path(otp_delivery_preference: delivery_method)
    end
    fill_in :code, with: '123456'
    click_submit_default

    expect(page).to have_content(t('two_factor_authentication.max_otp_login_attempts_reached'))
    expect_user_to_be_rate_limitted
    expect_rate_limitting_to_expire
  end

  def expect_user_to_be_rate_limitted
    visit account_path
    expect(page).to have_current_path(new_user_session_path)

    visit root_path
    signin(
      user.confirmed_email_addresses.first.email,
      user.password || Features::SessionHelper::VALID_PASSWORD,
    )

    expect(page).to have_content(t('two_factor_authentication.max_generic_login_attempts_reached'))
  end

  def expect_rate_limitting_to_expire
    travel (IdentityConfig.store.lockout_period_in_minutes + 1).minutes do
      visit root_path

      signin(
        user.confirmed_email_addresses.first.email,
        user.password || Features::SessionHelper::VALID_PASSWORD,
      )

      expect(page).to_not have_content(
        t('two_factor_authentication.max_generic_login_attempts_reached'),
      )
    end
  end
end
