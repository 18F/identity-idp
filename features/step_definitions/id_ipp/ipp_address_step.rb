# frozen_string_literal: true

Given('the user has completed IDV steps before the address page') do
  complete_ipp_steps_before_address(@user)
end

When('the user visits the in-person address page') do
  visit idv_in_person_address_url
end

Then('the page displays the correct heading and button text') do
  expect(page).to have_content(t('forms.buttons.continue'))
  expect(page).to have_content(t('in_person_proofing.headings.address'))
end

When('the user clicks on the cancel link') do
  click_link t('links.cancel')
end

When('the user chooses to start over') do
  click_on t('idv.cancel.actions.start_over')
end

Then('the user is navigated to the welcome page') do
  expect(page).to have_current_path(idv_welcome_path)
end

When('the user chooses to keep going') do
  click_on t('idv.cancel.actions.keep_going')
end

Then('the user remains on the in-person address page') do
  expect(page).to have_current_path(idv_in_person_address_url)
end

When('the user fills out the address form with valid data') do
  fill_out_address_form_ok
end

When('the user clicks continue') do
  click_idv_continue
end

Then('the user is navigated to the SSN page') do
  expect(page).to have_current_path(idv_in_person_ssn_url)
end

When('the user clicks on the change address link') do
  find(:xpath, "//a[@aria-label='#{I18n.t('idv.buttons.change_address_label')}']").click
end

Then('the address fields are pre-populated with the user\'s information') do
  expect(page).to have_field(t('idv.form.address1'), with: InPersonHelper::GOOD_ADDRESS1)
  expect(page).to have_field(t('idv.form.city'), with: InPersonHelper::GOOD_CITY)
  expect(page).to have_field(t('idv.form.zipcode'), with: InPersonHelper::GOOD_ZIPCODE)
  expect(page).to have_field(t('idv.form.state'), with: Idp::Constants::MOCK_IDV_APPLICANT_STATE)
end

When('the user fills out the address form with invalid characters') do
  fill_out_address_form_ok(same_address_as_id: false)
  fill_in t('idv.form.address1'), with: '#1 $treet'
  fill_in t('idv.form.address2'), with: 'Gr@nd Lañe^'
  fill_in t('idv.form.city'), with: 'N3w C!ty'
  click_idv_continue
end

Then('the user sees validation error messages') do
  expect(page).to have_content(I18n.t('in_person_proofing.form.address.errors.unsupported_chars', char_list: '$'))
  expect(page).to have_content(I18n.t('in_person_proofing.form.address.errors.unsupported_chars', char_list: '@, ^'))
  expect(page).to have_content(I18n.t('in_person_proofing.form.address.errors.unsupported_chars', char_list: '!, 3'))
end

When('the user submits an invalid zip code') do
  fill_in t('idv.form.zipcode'), with: 'invalid input'
  click_idv_continue
end

Then('the user sees an error message') do
  expect(page).to have_css('.usa-error-message', text: t('idv.errors.pattern_mismatch.zipcode'))
end

When('the user submits a valid zip code') do
  fill_in t('idv.form.zipcode'), with: '123456789'
  click_idv_continue
end

When('the user selects {string} from the state dropdown') do |state|
  select state, from: t('idv.form.state')
end

Then('the user sees the address hints') do
  expect(page).to have_content(I18n.t('in_person_proofing.form.state_id.address1_hint'))
  expect(page).to have_content(I18n.t('in_person_proofing.form.state_id.address2_hint'))
end

def complete_ipp_steps_before_address(user)
  begin_in_person_proofing_with_opt_in_ipp_enabled_and_opting_in
  complete_prepare_step(user)
  complete_location_step
  fill_out_state_id_form_ok(same_address_as_id: false)
  click_idv_continue
end
