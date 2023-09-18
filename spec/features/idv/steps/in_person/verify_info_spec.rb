require 'rails_helper'
require 'axe-rspec'

RSpec.describe 'doc auth IPP VerifyInfo', js: true do
  include IdvStepHelper
  include InPersonHelper

  let(:user) { user_with_2fa }
  let(:fake_analytics) { FakeAnalytics.new(user: user) }
  let(:enrollment) { InPersonEnrollment.new }

  before do
    allow(IdentityConfig.store).to receive(:in_person_proofing_enabled).and_return(true)
    allow_any_instance_of(ApplicationController).to receive(:analytics).and_return(fake_analytics)
    allow(user).to receive(:enrollment).
      and_return(enrollment)
  end

  it 'provides back buttons for address, state ID, and SSN that discard changes',
     allow_browser_log: true do
    sign_in_and_2fa_user(user)
    begin_in_person_proofing(user)
    complete_prepare_step(user)
    complete_location_step(user)
    complete_state_id_step(user)
    complete_ssn_step(user)

    # verify page
    expect_in_person_step_indicator_current_step(t('step_indicator.flows.idv.verify_info'))
    expect(page).to have_current_path(idv_in_person_verify_info_path)
    expect(page).to have_content(t('headings.verify'))
    expect(page).to have_text(InPersonHelper::GOOD_FIRST_NAME)
    expect(page).to have_text(InPersonHelper::GOOD_LAST_NAME)
    expect(page).to have_text(InPersonHelper::GOOD_DOB_FORMATTED_EVENT)
    expect(page).to have_text(InPersonHelper::GOOD_STATE_ID_NUMBER)
    expect(page).to have_text(InPersonHelper::GOOD_IDENTITY_DOC_ADDRESS1).twice
    expect(page).to have_text(InPersonHelper::GOOD_IDENTITY_DOC_ADDRESS2).twice
    expect(page).to have_text(InPersonHelper::GOOD_IDENTITY_DOC_CITY).twice
    expect(page).to have_text(Idp::Constants::MOCK_IDV_APPLICANT[:state_id_jurisdiction], count: 3)
    expect(page).to have_text(InPersonHelper::GOOD_IDENTITY_DOC_ZIPCODE).twice
    expect(page).to have_text(DocAuthHelper::GOOD_SSN_MASKED)

    # click update state ID button
    click_button t('idv.buttons.change_state_id_label')
    expect(page).to have_content(t('in_person_proofing.headings.update_state_id'))
    fill_in t('in_person_proofing.form.state_id.first_name'), with: 'bad first name'
    click_doc_auth_back_link
    expect(page).to have_content(t('headings.verify'))
    expect(page).to have_current_path(idv_in_person_verify_info_path)
    expect(page).to have_text(InPersonHelper::GOOD_FIRST_NAME)
    expect(page).not_to have_text('bad first name')

    # click update address button
    click_button t('idv.buttons.change_address_label')
    expect(page).to have_content(t('in_person_proofing.headings.update_address'))
    fill_in t('idv.form.address1'), with: 'bad address'
    click_doc_auth_back_link
    expect(page).to have_content(t('headings.verify'))
    expect(page).to have_current_path(idv_in_person_verify_info_path)
    expect(page).to have_text(InPersonHelper::GOOD_IDENTITY_DOC_ADDRESS1)
    expect(page).not_to have_text('bad address')

    # click update ssn button
    click_on t('idv.buttons.change_ssn_label')
    expect(page).to have_content(t('doc_auth.headings.ssn_update'))
    fill_out_ssn_form_fail
    click_doc_auth_back_link
    expect(page).to have_content(t('headings.verify'))
    expect(page).to have_current_path(idv_in_person_verify_info_path)
    expect(page).to have_text(DocAuthHelper::GOOD_SSN_MASKED)

    complete_verify_step(user)

    # phone page
    expect(page).to have_content(t('titles.idv.phone'))
  end

  it 'returns the user to the verify info page when updates are made',
     allow_browser_log: true do
    sign_in_and_2fa_user(user)
    begin_in_person_proofing(user)
    complete_prepare_step(user)
    complete_location_step(user)
    complete_state_id_step(user)
    complete_ssn_step(user)

    # verify page
    expect_in_person_step_indicator_current_step(t('step_indicator.flows.idv.verify_info'))
    expect(page).to have_current_path(idv_in_person_verify_info_path)
    expect(page).to have_content(t('headings.verify'))
    expect(page).to have_current_path(idv_in_person_verify_info_path)
    expect(page).to have_text(InPersonHelper::GOOD_FIRST_NAME)
    expect(page).to have_text(InPersonHelper::GOOD_LAST_NAME)
    expect(page).to have_text(InPersonHelper::GOOD_DOB_FORMATTED_EVENT)
    expect(page).to have_text(InPersonHelper::GOOD_STATE_ID_NUMBER)
    expect(page).to have_text(InPersonHelper::GOOD_IDENTITY_DOC_ADDRESS1).twice
    expect(page).to have_text(InPersonHelper::GOOD_IDENTITY_DOC_ADDRESS2).twice
    expect(page).to have_text(InPersonHelper::GOOD_IDENTITY_DOC_CITY).twice
    expect(page).to have_text(Idp::Constants::MOCK_IDV_APPLICANT[:state_id_jurisdiction], count: 3)
    expect(page).to have_text(InPersonHelper::GOOD_IDENTITY_DOC_ZIPCODE).twice
    expect(page).to have_text(DocAuthHelper::GOOD_SSN_MASKED)

    # click update state ID button
    click_button t('idv.buttons.change_state_id_label')
    expect(page).to have_content(t('in_person_proofing.headings.update_state_id'))
    fill_in t('in_person_proofing.form.state_id.first_name'), with: 'Natalya'
    click_button t('forms.buttons.submit.update')
    expect(page).to have_content(t('headings.verify'))
    expect(page).to have_current_path(idv_in_person_verify_info_path)
    expect(page).to have_text('Natalya')
    expect(page).not_to have_text('bad first name')

    # click update address button
    click_button t('idv.buttons.change_address_label')
    expect(page).to have_content(t('in_person_proofing.headings.update_address'))
    fill_in t('idv.form.address1'), with: '987 Fake St.'
    click_button t('forms.buttons.submit.update')
    expect(page).to have_content(t('headings.verify'))
    expect(page).to have_current_path(idv_in_person_verify_info_path)
    expect(page).to have_text('987 Fake St.')
    expect(page).not_to have_text('bad address')

    # click update ssn button
    click_on t('idv.buttons.change_ssn_label')
    expect(page).to have_content(t('doc_auth.headings.ssn_update'))
    fill_in t('idv.form.ssn_label'), with: '900-12-2345'
    click_button t('forms.buttons.submit.update')
    expect(page).to have_content(t('headings.verify'))
    expect(page).to have_current_path(idv_in_person_verify_info_path)
    expect(page).to have_text('9**-**-***5')

    complete_verify_step(user)

    # phone page
    expect(page).to have_content(t('titles.idv.phone'))
  end

  it 'does not proceed to the next page if resolution fails',
     allow_browser_log: true do
    sign_in_and_2fa_user

    begin_in_person_proofing(user)
    complete_prepare_step(user)
    complete_location_step(user)
    complete_state_id_step(user)
    fill_out_ssn_form_with_ssn_that_fails_resolution
    click_idv_continue
    click_idv_continue

    expect(page).to have_current_path(idv_session_errors_warning_path(flow: 'in_person'))
    click_on t('idv.failure.button.warning')

    expect(page).to have_current_path(idv_in_person_verify_info_path)
  end

  it 'proceeds to the next page if resolution passes',
     allow_browser_log: true do
    sign_in_and_2fa_user
    begin_in_person_proofing(user)
    complete_prepare_step(user)
    complete_location_step(user)
    complete_state_id_step(user)
    complete_ssn_step(user)
    click_idv_continue

    expect(page).to have_content(t('titles.idv.phone'))
    expect(fake_analytics).to have_logged_event(
      'IdV: doc auth verify proofing results',
      hash_including(analytics_id: 'In Person Proofing'),
    )
  end
end
