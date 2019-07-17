shared_examples 'verification step max attempts' do |step, sp|
  let(:locale) { LinkLocaleResolver.locale }
  let(:user) { user_with_2fa }
  let(:step_locale_key) do
    return :sessions if step == :profile
    step
  end

  before do
    start_idv_from_sp(sp)
    complete_idv_steps_before_step(step, user)
  end

  context 'after completing the max number of attempts' do
    before do
      if step == :profile
        perfom_maximum_allowed_idv_step_attempts { fill_out_idv_form_fail }
      elsif step == :phone
        perfom_maximum_allowed_idv_step_attempts { fill_out_phone_form_fail }
      end
    end

    scenario 'more than 3 attempts in 24 hours prevents further attempts' do
      # Blocked if visiting verify directly
      visit idv_url
      if step == :phone
        advance_to_phone_step
        expect_user_to_fail_at_phone_step
      else
        expect_user_to_fail_at_profile_step
      end

      # Blocked if visiting from an SP
      visit_idp_from_sp_with_loa3(:oidc)
      if step == :phone
        advance_to_phone_step
        expect_user_to_fail_at_phone_step
      else
        expect_user_to_fail_at_profile_step
      end

      if step == :sessions
        user.reload

        expect(user.idv_attempted_at).to_not be_nil
      end
    end

    scenario 'after 24 hours the user can retry and complete idv' do
      visit account_path
      first(:link, t('links.sign_out')).click
      reattempt_interval = (Figaro.env.idv_attempt_window_in_hours.to_i + 1).hours

      Timecop.travel reattempt_interval do
        visit_idp_from_sp_with_loa3(:oidc)
        sign_in_live_with_2fa(user)

        expect(page).to_not have_content(t("idv.failure.#{step_locale_key}.heading"))
        expect(current_url).to eq(idv_jurisdiction_url)

        fill_out_idv_jurisdiction_ok
        click_idv_continue
        complete_idv_profile_ok(user)
        click_acknowledge_personal_key
        click_idv_continue

        expect(current_url).to start_with('http://localhost:7654/auth/result')
      end
    end

    scenario 'user sees the failure screen' do
      expect(page).to have_content(t("idv.failure.#{step_locale_key}.heading"))
      expect(page).to have_content(strip_tags(t("idv.failure.#{step_locale_key}.fail_html")))
    end
  end

  context 'after completing one less than the max attempts' do
    it 'allows the user to continue if their last attempt is successful' do
      max_attempts_less_one.times do
        fill_out_idv_form_fail if step == :profile
        fill_out_phone_form_fail if step == :phone
        click_continue
        click_on t('idv.failure.button.warning')
      end

      fill_out_idv_form_ok if step == :profile
      fill_out_phone_form_ok if step == :phone
      click_continue

      if step == :profile
        expect(page).to have_content(t('idv.titles.session.success'))
        expect(page).to have_current_path(idv_session_success_path)
      elsif step == :phone
        expect(page).to have_content(t('idv.titles.otp_delivery_method'))
        expect(page).to have_current_path(idv_otp_delivery_method_path)
      end
    end
  end

  def perfom_maximum_allowed_idv_step_attempts
    max_attempts_less_one.times do
      yield
      click_idv_continue
      click_on t('idv.failure.button.warning')
    end
    yield
    click_idv_continue
  end

  def expect_user_to_fail_at_profile_step
    expect(page).to have_content(t('idv.titles.hardfail', app: 'login.gov'))
    expect(current_url).to eq(idv_fail_url)
  end

  def expect_user_to_fail_at_phone_step
    expect(page).to have_content(t("idv.failure.#{step_locale_key}.heading"))
    expect(current_url).to eq(idv_phone_failure_url(:fail, locale: locale))
  end

  def advance_to_phone_step
    # Currently on the session success path
    # Click continue to advance to the phone step
    click_idv_continue
  end
end
