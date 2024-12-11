# frozen_string_literal: true

Given('a user is logged in') do
  @user = user_with_2fa
  @service_provider = create(:service_provider, :active, :in_person_proofing_enabled)

  visit_idp_from_sp_with_ial2(:oidc, **{ client_id: @service_provider.issuer })
  sign_in_via_branded_page(@user)
end

Given('the user begins in-person proofing') do
  begin_in_person_proofing_with_opt_in_ipp_enabled_and_opting_in
end

Given('the user completes the prepared step') do
  complete_prepare_step(@user)
end

Given('the user selects a post office') do
  complete_location_step
end

Given('the user submits a state id') do
  complete_state_id_controller(@user)
end

Given('the user submits an ssn') do
  complete_ssn_step(@user)
end

Given('the user verifies their information') do
  complete_verify_step(@user)
end

Given('the user submits their phone number for verification') do
  fill_out_phone_form_ok(MfaContext.new(@user).phone_configurations.first.phone)
  click_idv_send_security_code
end

Given('the user verifies their phone number') do
  fill_in_code_with_last_phone_otp
  click_submit_default
end

Given('the user submits their password') do
  complete_enter_password_step(@user)
end

Then('the user is navigated to the personal key page') do
  expect(page).to have_content(t('titles.idv.personal_key'))
  expect(page).to have_current_path(idv_personal_key_path)
end

Then('the user has a {string} in-person enrollment') do |status|
  expect(@user.in_person_enrollments.first).to have_attributes(
    status: status,
  )
end

Then('the user has a pending profile') do
  expect(@user.in_person_enrollments.first.profile).to have_attributes(
    active: false,
    deactivation_reason: nil,
    in_person_verification_pending_at: be_kind_of(Time),
  )
end
