require 'rails_helper'

RSpec.feature 'Users pending ThreatMetrix review', :js do
  include IdvStepHelper
  include OidcAuthHelper
  include IrsAttemptsApiTrackingHelper
  include DocAuthHelper

  before do
    allow(IdentityConfig.store).to receive(:proofing_device_profiling).and_return(:enabled)
    allow(IdentityConfig.store).to receive(:lexisnexis_threatmetrix_org_id).and_return('test_org')
  end

  let(:service_provider) do
    create(
      :service_provider,
      active: true,
      redirect_uris: ['http://localhost:7654/auth/result'],
      ial: 2,
      irs_attempts_api_enabled: true,
    )
  end

  scenario 'users pending ThreatMetrix see sad face screen and cannot perform idv' do
    allow(IdentityConfig.store).to receive(:otp_delivery_blocklist_maxretry).and_return(300)
    user = create(:user, :fully_registered)

    start_idv_from_sp
    sign_in_and_2fa_user(user)
    complete_doc_auth_steps_before_ssn_step
    select 'Reject', from: :mock_profiling_result
    complete_ssn_step
    click_idv_continue
    complete_phone_step(user)
    complete_enter_password_step(user)
    acknowledge_and_confirm_personal_key

    expect(page).to have_content(t('idv.failure.setup.heading'))
    expect(page).to have_current_path(idv_please_call_path)

    # User unable to sign into OIDC with IdV
    set_new_browser_session
    start_idv_from_sp(:oidc)
    sign_in_live_with_2fa(user)

    expect(page).to have_content(t('idv.failure.setup.heading'))
    expect(page).to have_current_path(idv_please_call_path)

    # User unable to sign into SAML with IdV
    set_new_browser_session
    start_idv_from_sp(:saml)
    sign_in_live_with_2fa(user)

    expect(page).to have_content(t('idv.failure.setup.heading'))
    expect(page).to have_current_path(idv_please_call_path)

    # User able to sign for IAL1
    set_new_browser_session
    visit_idp_from_sp_with_ial1(:oidc)
    sign_in_live_with_2fa(user)
    click_agree_and_continue

    expect(current_path).to eq('/auth/result')
  end

  scenario 'users rejected from fraud review cannot perform idv' do
    user = create(:user, :fraud_rejection)

    start_idv_from_sp
    sign_in_live_with_2fa(user)

    # User is redirected on IdV sign in
    expect(page).to have_content(t('idv.failure.verify.heading'))
    expect(page).to have_current_path(idv_not_verified_path)

    visit idv_url

    # User cannot enter IdV flow
    expect(page).to have_content(t('idv.failure.verify.heading'))
    expect(page).to have_current_path(idv_not_verified_path)

    # User able to sign for IAL1
    set_new_browser_session
    visit_idp_from_sp_with_ial1(:oidc)
    sign_in_live_with_2fa(user)
    click_agree_and_continue

    expect(current_path).to eq('/auth/result')
  end

  scenario 'users ThreatMetrix Pass, it logs idv_tmx_fraud_check event' do
    freeze_time do
      complete_all_idv_steps_with(threatmetrix: 'Pass')
    end
  end

  scenario 'users pending ThreatMetrix Reject, it logs idv_tmx_fraud_check event' do
    freeze_time do
      expect_pending_failure_reason(threatmetrix: 'Reject')
    end
  end

  scenario 'users pending ThreatMetrix Review, it logs idv_tmx_fraud_check event' do
    freeze_time do
      expect_pending_failure_reason(threatmetrix: 'Review')
    end
  end

  scenario 'users pending ThreatMetrix No Result, it results in an error', :js do
    freeze_time do
      user = create(:user, :fully_registered)
      visit_idp_from_ial1_oidc_sp(
        client_id: service_provider.issuer,
      )
      visit root_path
      sign_in_and_2fa_user(user)
      complete_doc_auth_steps_before_ssn_step
      select 'No Result', from: :mock_profiling_result
      complete_ssn_step
      click_idv_continue

      expect(page).to have_content(t('idv.failure.sessions.exception'))
      expect(page).to have_current_path(idv_session_errors_exception_path)
    end
  end

  def expect_pending_failure_reason(threatmetrix:)
    complete_all_idv_steps_with(threatmetrix:)
    expect(page).to have_content(t('idv.failure.setup.heading'))
    expect(page).to have_current_path(idv_please_call_path)
  end
end
