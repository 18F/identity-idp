shared_examples 'verification step max attempts' do |step, sp|
  include ActionView::Helpers::DateHelper

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
    around do |ex|
      freeze_time { ex.run }
    end

    before do
      perfom_maximum_allowed_idv_step_attempts(step) { fill_out_phone_form_fail }
    end

    scenario 'more than 3 attempts in 24 hours prevents further attempts' do
      # Blocked if visiting verify directly
      visit idv_url
      expect_user_to_fail_at_phone_step

      # Blocked if visiting from an SP
      visit_idp_from_sp_with_ial2(:oidc)
      expect_user_to_fail_at_phone_step
    end

    scenario 'user sees the failure screen' do
      expect(page).to have_content(t("idv.failure.#{step_locale_key}.heading"))
      expect(page).to have_content(
        strip_tags(
          t(
            'idv.failure.phone.fail_html',
            timeout: distance_of_time_in_words(
              IdentityConfig.store.idv_attempt_window_in_hours.hours,
            ),
          ),
        ),
      )
    end
  end

  context 'after completing one less than the max attempts' do
    it 'allows the user to continue if their last attempt is successful' do
      (Throttle.max_attempts(:proof_address) - 1).times do
        fill_out_phone_form_fail
        click_idv_continue_for_step(step)
        click_on t('idv.failure.button.warning')
      end

      fill_out_phone_form_ok
      click_idv_continue_for_step(step)

      expect(page).to have_content(t('titles.idv.enter_one_time_code'))
      expect(page).to have_current_path(idv_otp_verification_path)
    end
  end

  def perfom_maximum_allowed_idv_step_attempts(step)
    (Throttle.max_attempts(:proof_address) - 1).times do
      yield
      click_idv_continue_for_step(step)
      click_on t('idv.failure.button.warning')
    end
    yield
    click_idv_continue_for_step(step)
  end

  def expect_user_to_fail_at_phone_step
    expect(page).to have_content(t("idv.failure.#{step_locale_key}.heading"))
    expect(current_url).to eq(idv_phone_errors_failure_url(locale: locale))
    expect(page).to have_link(t('idv.troubleshooting.options.verify_by_mail'))
  end
end
