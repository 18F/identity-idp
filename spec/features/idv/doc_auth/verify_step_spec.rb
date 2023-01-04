require 'rails_helper'

feature 'doc auth verify step', :js do
  include IdvStepHelper
  include DocAuthHelper

  let(:skip_step_completion) { false }
  let(:max_attempts) { Throttle.max_attempts(:idv_resolution) }
  let(:fake_analytics) { FakeAnalytics.new }
  let(:fake_attempts_tracker) { IrsAttemptsApiTrackingHelper::FakeAttemptsTracker.new }
  before do
    allow_any_instance_of(ApplicationController).to receive(:analytics).and_return(fake_analytics)
    allow_any_instance_of(ApplicationController).to receive(:irs_attempts_api_tracker).
      and_return(fake_attempts_tracker)
  end

  it 'displays the expected content' do
    sign_in_and_2fa_user
    complete_doc_auth_steps_before_verify_step

    expect(page).to have_current_path(idv_doc_auth_verify_step)
    expect(page).to have_content(t('headings.verify'))
    expect_step_indicator_current_step(t('step_indicator.flows.idv.verify_info'))

    # SSN is masked until revealed
    expect(page).to have_text('9**-**-***4')
    expect(page).not_to have_text(DocAuthHelper::GOOD_SSN)
    check t('forms.ssn.show')
    expect(page).not_to have_text('9**-**-***4')
    expect(page).to have_text(DocAuthHelper::GOOD_SSN)
  end

  it 'proceeds to the next page upon confirmation' do
    expect(fake_attempts_tracker).to receive(:idv_verification_submitted).with(
      success: true,
      failure_reason: nil,
      document_state: 'MT',
      document_number: '1111111111111',
      document_issued: '2019-12-31',
      document_expiration: '2099-12-31',
      first_name: 'FAKEY',
      last_name: 'MCFAKERSON',
      date_of_birth: '1938-10-06',
      address: '1 FAKE RD',
      ssn: '900-66-1234',
    )
    sign_in_and_2fa_user
    complete_doc_auth_steps_before_verify_step
    click_idv_continue

    expect(page).to have_current_path(idv_phone_path)
    expect(page).to have_content(t('doc_auth.forms.doc_success'))
    user = User.first
    expect(user.proofing_component.resolution_check).to eq(Idp::Constants::Vendors::LEXIS_NEXIS)
    expect(user.proofing_component.source_check).to eq(Idp::Constants::Vendors::AAMVA)
    expect(DocAuthLog.find_by(user_id: user.id).aamva).to eq(true)
    expect(fake_analytics).to have_logged_event(
      'IdV: doc auth optional verify_wait submitted',
      hash_including(address_edited: false),
    )
  end

  it 'proceeds to address page prepopulated with defaults if the user clicks change address' do
    sign_in_and_2fa_user
    complete_doc_auth_steps_before_verify_step
    click_button t('idv.buttons.change_address_label')

    expect(page).to have_current_path(idv_address_path)
    expect(page).to have_selector("input[value='1 FAKE RD']")
    expect(page).to have_selector("input[value='GREAT FALLS']")
    expect(page).to have_selector("input[value='59010']")
  end

  it 'tracks when the user edits their address' do
    sign_in_and_2fa_user
    complete_doc_auth_steps_before_verify_step

    click_button t('idv.buttons.change_address_label')
    fill_out_address_form_ok
    click_button t('forms.buttons.submit.update') # address form

    click_idv_continue

    expect(fake_analytics).to have_logged_event(
      'IdV: doc auth optional verify_wait submitted',
      hash_including(address_edited: true),
    )
  end

  it 'allows user to back out of editing their address and proceed' do
    sign_in_and_2fa_user
    complete_doc_auth_steps_before_verify_step

    click_button t('idv.buttons.change_address_label')
    fill_out_address_form_fail
    click_doc_auth_back_link

    click_idv_continue

    expect(fake_analytics).to have_logged_event(
      'IdV: doc auth optional verify_wait submitted',
      hash_including(address_edited: false),
    )
  end

  it 'proceeds to the ssn page if the user clicks change ssn and allows user to go back' do
    sign_in_and_2fa_user
    complete_doc_auth_steps_before_verify_step

    click_button t('idv.buttons.change_ssn_label')

    expect(page).to have_current_path(idv_doc_auth_ssn_step)
    expect(page).to have_content(t('doc_auth.headings.ssn_update'))

    click_button t('forms.buttons.back')
    expect(page).to have_current_path(idv_doc_auth_verify_step)
  end

  it 'does not proceed to the next page if resolution fails' do
    expect(fake_attempts_tracker).to receive(:idv_verification_submitted).with(
      success: false,
      failure_reason: { ssn: ['Unverified SSN.'] },
      document_state: 'MT',
      document_number: '1111111111111',
      document_issued: '2019-12-31',
      document_expiration: '2099-12-31',
      first_name: 'FAKEY',
      last_name: 'MCFAKERSON',
      date_of_birth: '1938-10-06',
      address: '1 FAKE RD',
      ssn: '123-45-6666',
    )
    sign_in_and_2fa_user
    complete_doc_auth_steps_before_ssn_step
    fill_out_ssn_form_with_ssn_that_fails_resolution
    click_idv_continue
    click_idv_continue

    expect(fake_analytics).to have_logged_event(
      'IdV: doc auth warning visited',
      step_name: 'Idv::Steps::VerifyWaitStepShow',
      remaining_attempts: 4,
    )
    expect(page).to have_current_path(idv_session_errors_warning_path)

    click_on t('idv.failure.button.warning')

    expect(page).to have_current_path(idv_doc_auth_verify_step)
  end

  it 'does not proceed to the next page if resolution raises an exception' do
    expect(fake_attempts_tracker).to receive(:idv_verification_submitted).with(
      success: false,
      failure_reason: nil,
      document_state: 'MT',
      document_number: '1111111111111',
      document_issued: '2019-12-31',
      document_expiration: '2099-12-31',
      first_name: 'FAKEY',
      last_name: 'MCFAKERSON',
      date_of_birth: '1938-10-06',
      address: '1 FAKE RD',
      ssn: '000-00-0000',
    )
    sign_in_and_2fa_user
    complete_doc_auth_steps_before_ssn_step
    fill_out_ssn_form_with_ssn_that_raises_exception
    click_idv_continue
    click_idv_continue

    expect(fake_analytics).to have_logged_event(
      'IdV: doc auth exception visited',
      step_name: 'Idv::Steps::VerifyWaitStepShow',
      remaining_attempts: 5,
    )
    expect(page).to have_current_path(idv_session_errors_exception_path)

    click_on t('idv.failure.button.warning')

    expect(page).to have_current_path(idv_doc_auth_verify_step)
  end

  it 'throttles resolution and continues when it expires' do
    expect(fake_attempts_tracker).to receive(:idv_verification_rate_limited)
    sign_in_and_2fa_user
    complete_doc_auth_steps_before_ssn_step
    fill_out_ssn_form_with_ssn_that_fails_resolution
    click_idv_continue
    (max_attempts - 1).times do
      click_idv_continue
      expect(page).to have_current_path(idv_session_errors_warning_path)
      visit idv_doc_auth_verify_step
    end
    click_idv_continue
    expect(page).to have_current_path(idv_session_errors_failure_path)
    expect(fake_analytics).to have_logged_event(
      'Throttler Rate Limit Triggered',
      throttle_type: :idv_resolution,
      step_name: 'Idv::Steps::VerifyWaitStepShow',
    )

    travel_to(IdentityConfig.store.idv_attempt_window_in_hours.hours.from_now + 1) do
      sign_in_and_2fa_user
      complete_doc_auth_steps_before_verify_step
      click_idv_continue

      expect(page).to have_current_path(idv_phone_path)
    end
  end

  context 'when the user lives in an AAMVA supported state' do
    it 'performs a resolution and state ID check' do
      allow(IdentityConfig.store).to receive(:aamva_supported_jurisdictions).and_return(
        [Idp::Constants::MOCK_IDV_APPLICANT[:state_id_jurisdiction]],
      )
      user = create(:user, :signed_up)
      expect_any_instance_of(Idv::Agent).
        to receive(:proof_resolution).
        with(
          anything,
          should_proof_state_id: true,
          trace_id: anything,
          threatmetrix_session_id: anything,
          user_id: user.id,
          request_ip: kind_of(String),
        ).
        and_call_original

      sign_in_and_2fa_user(user)
      complete_doc_auth_steps_before_verify_step
      click_idv_continue

      expect(DocAuthLog.find_by(user_id: user.id).aamva).not_to be_nil
    end
  end

  context 'when the user does not live in an AAMVA supported state' do
    it 'does not perform the state ID check' do
      allow(IdentityConfig.store).to receive(:aamva_supported_jurisdictions).and_return(
        IdentityConfig.store.aamva_supported_jurisdictions -
          [Idp::Constants::MOCK_IDV_APPLICANT[:state_id_jurisdiction]],
      )
      user = create(:user, :signed_up)
      expect_any_instance_of(Idv::Agent).
        to receive(:proof_resolution).
        with(
          anything,
          should_proof_state_id: false,
          trace_id: anything,
          threatmetrix_session_id: anything,
          user_id: user.id,
          request_ip: kind_of(String),
        ).
        and_call_original

      sign_in_and_2fa_user(user)
      complete_doc_auth_steps_before_verify_step
      click_idv_continue

      expect(DocAuthLog.find_by(user_id: user.id).aamva).to be_nil
    end
  end

  context 'when the SP is in the AAMVA banlist' do
    it 'does not perform the state ID check' do
      allow(IdentityConfig.store).to receive(:aamva_sp_banlist_issuers).
        and_return('["urn:gov:gsa:openidconnect:sp:server"]')
      user = create(:user, :signed_up)
      expect_any_instance_of(Idv::Agent).
        to receive(:proof_resolution).
        with(
          anything,
          should_proof_state_id: false,
          trace_id: anything,
          threatmetrix_session_id: anything,
          user_id: user.id,
          request_ip: kind_of(String),
        ).
        and_call_original

      visit_idp_from_sp_with_ial1(:oidc)
      sign_in_and_2fa_user(user)
      complete_doc_auth_steps_before_verify_step
      click_idv_continue

      expect(DocAuthLog.find_by(user_id: user.id).aamva).to be_nil
    end
  end

  context 'async missing' do
    it 'allows resubmitting form' do
      sign_in_and_2fa_user
      complete_doc_auth_steps_before_verify_step

      allow(DocumentCaptureSession).to receive(:find_by).
        and_return(nil)

      click_idv_continue
      expect(fake_analytics).to have_logged_event('Proofing Resolution Result Missing')
      expect(page).to have_content(t('idv.failure.timeout'))
      expect(page).to have_current_path(idv_doc_auth_verify_step)
      allow(DocumentCaptureSession).to receive(:find_by).and_call_original
      click_idv_continue
      expect(page).to have_current_path(idv_phone_path)
    end

    it 'tracks attempts tracker event with failure reason' do
      expect(fake_attempts_tracker).to receive(:idv_verification_submitted).with(
        success: false,
        failure_reason: {
          timeout:
            ['We are experiencing higher than usual wait time processing your request.'],
        },
        document_state: 'MT',
        document_number: '1111111111111',
        document_issued: '2019-12-31',
        document_expiration: '2099-12-31',
        first_name: 'FAKEY',
        last_name: 'MCFAKERSON',
        date_of_birth: '1938-10-06',
        address: '1 FAKE RD',
        ssn: '900-66-1234',
      )
      sign_in_and_2fa_user
      complete_doc_auth_steps_before_verify_step
      click_idv_continue
      expect(page).to have_content(t('idv.failure.timeout'))
      expect(page).to have_current_path(idv_doc_auth_verify_step)
    end
  end

  context 'async timed out' do
    it 'allows resubmitting form' do
      sign_in_and_2fa_user
      complete_doc_auth_steps_before_verify_step

      allow(DocumentCaptureSession).to receive(:find_by).
        and_return(nil)

      click_idv_continue
      expect(page).to have_content(t('idv.failure.timeout'))
      expect(page).to have_current_path(idv_doc_auth_verify_step)
      allow(DocumentCaptureSession).to receive(:find_by).and_call_original
      click_idv_continue
      expect(page).to have_current_path(idv_phone_path)
    end
  end
end
