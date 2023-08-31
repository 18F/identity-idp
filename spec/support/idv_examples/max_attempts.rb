RSpec.shared_examples 'verification step max attempts' do |step, sp|
  include ActionView::Helpers::DateHelper

  let(:user) { user_with_2fa }

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

    scenario 'user sees the failure screen', js: true do
      expect(page).to have_content(t('idv.failure.phone.rate_limited.heading'))
      expect(page).to have_content(
        strip_tags(
          t(
            'idv.failure.phone.rate_limited.body',
            time_left: distance_of_time_in_words(
              IdentityConfig.store.idv_attempt_window_in_hours.hours,
            ),
          ),
        ),
      )
    end
  end

  context 'after completing one less than the max attempts' do
    it 'allows the user to continue if their last attempt is successful' do
      (RateLimiter.max_attempts(:proof_address) - 1).times do
        fill_out_phone_form_fail
        click_idv_continue_for_step(step)
        click_on t('idv.failure.phone.warning.try_again_button')
      end

      fill_out_phone_form_ok
      verify_phone_otp
      expect(page).to have_current_path(idv_review_path, wait: 10)
    end
  end

  def perfom_maximum_allowed_idv_step_attempts(step)
    (RateLimiter.max_attempts(:proof_address) - 1).times do
      yield
      click_idv_continue_for_step(step)
      click_on t('idv.failure.phone.warning.try_again_button')
    end
    yield
    click_idv_continue_for_step(step)
  end

  def expect_user_to_fail_at_phone_step
    expect(page).to have_content(t('idv.failure.phone.rate_limited.heading'))
    expect(current_url).to eq(idv_phone_errors_failure_url)
    expect(page).to have_link(t('idv.failure.phone.rate_limited.gpo.button'))
  end
end
