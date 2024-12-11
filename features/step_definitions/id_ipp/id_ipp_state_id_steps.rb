# frozen_string_literal: true

When('the user reaches the state id page') do
  complete_ipp_steps_before_state_id_controller(@user)
end

Then('the state id form is present') do
  expect(page).to have_current_path(idv_in_person_state_id_path, wait: 10)
  expect(page).to have_content(strip_nbsp(t('in_person_proofing.headings.state_id_milestone_2')))
  expect(page).to have_field(t('in_person_proofing.form.state_id.first_name'))
  expect(page).to have_field(t('in_person_proofing.form.state_id.last_name'))
  expect(page).to have_field(t('components.memorable_date.month'))
  expect(page).to have_field(t('components.memorable_date.day'))
  expect(page).to have_field(t('components.memorable_date.year'))
  expect(page).to have_field(t('in_person_proofing.form.state_id.state_id_jurisdiction'))
  expect(page).to have_field(t('in_person_proofing.form.state_id.state_id_number'))
  expect(page).to have_field(t('in_person_proofing.form.state_id.address1'))
  expect(page).to have_field(t('in_person_proofing.form.state_id.address2'))
  expect(page).to have_field(t('in_person_proofing.form.state_id.city'))
  expect(page).to have_field(t('in_person_proofing.form.state_id.zipcode'))
  expect(page).to have_field(t('in_person_proofing.form.state_id.identity_doc_address_state'))
  expect(page).to have_content(
    strip_nbsp(t('in_person_proofing.form.state_id.same_address_as_id_yes')),
  )
  expect(page).to have_content(
    strip_nbsp(t('in_person_proofing.form.state_id.same_address_as_id_no')),
  )
  expect(page).to have_content(t('forms.buttons.continue'))
end

def complete_ipp_steps_before_state_id_controller(user)
  begin_in_person_proofing_with_opt_in_ipp_enabled_and_opting_in
  complete_prepare_step(user)
  complete_location_step
end
