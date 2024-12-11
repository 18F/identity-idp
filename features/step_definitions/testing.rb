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

When('I run cucumber') do
end

Then('this should pass') do
  expect(true).to be(true)
end
