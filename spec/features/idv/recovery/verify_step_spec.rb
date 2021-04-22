require 'rails_helper'

feature 'recovery verify step' do
  include IdvStepHelper
  include DocAuthHelper
  include RecoveryHelper

  let(:ial2_step_indicator_enabled) { true }
  let(:user) { create(:user, :signed_up, :with_phone) }
  let(:good_ssn) { '666-66-1234' }
  let(:profile) { create(:profile, :active, :verified, user: user, pii: saved_pii) }
  let(:saved_pii) do
    IdentityDocAuth::Mock::ResultResponseBuilder::DEFAULT_PII_FROM_DOC.merge(ssn: good_ssn)
  end
  let(:max_attempts) { idv_max_attempts }
  let(:fake_analytics) { FakeAnalytics.new }
  before do
    allow(IdentityConfig.store).to receive(:ial2_step_indicator_enabled).
      and_return(ial2_step_indicator_enabled)
    profile
    sign_in_before_2fa(user)
  end

  it 'is on the correct page' do
    complete_recovery_steps_before_verify_step
    expect(page).to have_current_path(idv_recovery_verify_step)
    expect(page).to have_content(t('doc_auth.headings.verify'))
  end

  it 'proceeds to the next page upon confirmation' do
    allow_any_instance_of(Idv::Steps::RecoverVerifyWaitStepShow).to receive(:saved_pii).
      and_return(saved_pii.to_json)
    complete_recovery_steps_before_verify_step
    click_idv_continue

    expect(page).to have_current_path(account_path)
  end

  it 'does not proceed to the next page if resolution fails' do
    complete_recovery_steps_before_ssn_step
    fill_out_ssn_form_with_ssn_that_fails_resolution
    click_idv_continue
    click_idv_continue

    expect(page).to have_current_path(idv_session_errors_recovery_warning_path)

    click_on t('idv.failure.button.warning')

    expect(page).to have_current_path(idv_recovery_verify_step)
  end

  it 'does not proceed to the next page if ssn is a duplicate' do
    complete_recovery_steps_before_ssn_step
    fill_out_ssn_form_with_duplicate_ssn
    click_idv_continue
    click_idv_continue

    expect(page).to have_current_path(idv_session_errors_recovery_warning_path)
  end

  it 'throttles resolution' do
    allow_any_instance_of(ApplicationController).to receive(:analytics).and_return(fake_analytics)
    complete_recovery_steps_before_ssn_step
    fill_out_ssn_form_with_ssn_that_fails_resolution
    click_idv_continue
    (max_attempts - 1).times do
      click_idv_continue
      expect(page).to have_current_path(idv_session_errors_recovery_warning_path)
      visit idv_recovery_verify_step
    end
    click_idv_continue
    expect(page).to have_current_path(idv_session_errors_recovery_failure_path)
    expect(fake_analytics).to have_logged_event(
      Analytics::THROTTLER_RATE_LIMIT_TRIGGERED,
      throttle_type: :idv_resolution,
    )
  end

  it 'throttles dup ssn and allows account reset on the error page' do
    allow_any_instance_of(ApplicationController).to receive(:analytics).and_return(fake_analytics)
    complete_recovery_steps_before_ssn_step
    fill_out_ssn_form_with_duplicate_ssn
    click_idv_continue
    (max_attempts - 1).times do
      click_idv_continue
      expect(page).to have_current_path(idv_session_errors_recovery_warning_path)
      visit idv_recovery_verify_step
    end
    click_idv_continue
    expect(page).to have_current_path(idv_session_errors_recovery_failure_path)
    expect(fake_analytics).to have_logged_event(
      Analytics::THROTTLER_RATE_LIMIT_TRIGGERED,
      throttle_type: :idv_resolution,
    )

    click_on t('two_factor_authentication.account_reset.reset_your_account')
    expect(page).to have_current_path(account_reset_request_path)
  end

  context 'ial2 step indicator enabled' do
    it 'shows the step indicator' do
      complete_recovery_steps_before_verify_step
      expect(page).to have_css(
        '.step-indicator__step--current',
        text: t('step_indicator.flows.idv.verify_info'),
      )
    end
  end

  context 'ial2 step indicator disabled' do
    let(:ial2_step_indicator_enabled) { false }

    it 'does not show the step indicator' do
      complete_recovery_steps_before_verify_step
      expect(page).not_to have_css('.step-indicator')
    end
  end

  context 'in progress' do
    it 'renders in progress form' do
      complete_recovery_steps_before_verify_step
      # the user gets shown the wait page until a result has been stored
      allow_any_instance_of(DocumentCaptureSession).to receive(:store_proofing_result).
        and_return(nil)
      click_continue

      expect(page).to have_current_path(idv_recovery_verify_wait_step)
    end
  end

  context 'timed out' do
    let(:fake_analytics) { FakeAnalytics.new }

    it 'allows resubmitting form' do
      complete_recovery_steps_before_verify_step

      allow_any_instance_of(Idv::Steps::RecoverVerifyWaitStepShow).to receive(:saved_pii).
        and_return(saved_pii.to_json)
      allow(DocumentCaptureSession).to receive(:find_by).
        and_return(nil)
      allow_any_instance_of(ApplicationController).
        to receive(:analytics).and_return(fake_analytics)

      click_continue

      expect(fake_analytics).to have_logged_event(Analytics::PROOFING_RESOLUTION_TIMEOUT, {})
      expect(page).to have_current_path(idv_recovery_verify_step)
      expect(page).to have_content t('idv.failure.timeout')
      allow(DocumentCaptureSession).to receive(:find_by).and_call_original
      click_continue
      expect(page).to have_current_path(account_path)
    end
  end
end
