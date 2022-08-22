require 'rails_helper'
require 'axe-rspec'

RSpec.describe 'doc auth IPP Verify Step', js: true do
  include IdvStepHelper
  include InPersonHelper

  before do
    allow(IdentityConfig.store).to receive(:in_person_proofing_enabled).and_return(true)
    allow(IdentityConfig.store).to receive(:idv_api_enabled_steps).and_return(
      ['password_confirm',
       'personal_key',
       'personal_key_confirm'],
    )
  end

  it 'provides back buttons for address, state ID, and SSN that discard changes',
     allow_browser_log: true do
    user = user_with_2fa

    sign_in_and_2fa_user(user)
    begin_in_person_proofing(user)
    complete_location_step(user)
    complete_prepare_step(user)
    complete_state_id_step(user)
    complete_address_step(user)
    complete_ssn_step(user)

    # verify page
    expect(page).to have_content(t('headings.verify'))
    expect(page).to have_text(InPersonHelper::GOOD_FIRST_NAME)
    expect(page).to have_text(InPersonHelper::GOOD_LAST_NAME)
    expect(page).to have_text(InPersonHelper::GOOD_DOB)
    expect(page).to have_text(InPersonHelper::GOOD_STATE_ID_NUMBER)
    expect(page).to have_text(InPersonHelper::GOOD_ADDRESS1)
    expect(page).to have_text(InPersonHelper::GOOD_CITY)
    expect(page).to have_text(InPersonHelper::GOOD_ZIPCODE)
    expect(page).to have_text(Idp::Constants::MOCK_IDV_APPLICANT[:state])
    expect(page).to have_text('9**-**-***4')

    # click update state ID button
    click_button t('idv.buttons.change_state_id_label')
    expect(page).to have_content(t('in_person_proofing.headings.update_state_id'))
    fill_in t('in_person_proofing.form.state_id.first_name'), with: 'bad first name'
    click_doc_auth_back_link
    expect(page).to have_content(t('headings.verify'))
    expect(page).to have_text(InPersonHelper::GOOD_FIRST_NAME)
    expect(page).not_to have_text('bad first name')

    # click update address button
    click_button t('idv.buttons.change_address_label')
    expect(page).to have_content(t('in_person_proofing.headings.update_address'))
    fill_in t('in_person_proofing.form.address.address1'), with: 'bad address'
    click_doc_auth_back_link
    expect(page).to have_content(t('headings.verify'))
    expect(page).to have_text(InPersonHelper::GOOD_ADDRESS1)
    expect(page).not_to have_text('bad address')

    # click update ssn button
    click_button t('idv.buttons.change_ssn_label')
    expect(page).to have_content(t('doc_auth.headings.ssn_update'))
    fill_out_ssn_form_fail
    click_doc_auth_back_link
    expect(page).to have_content(t('headings.verify'))
    expect(page).to have_text('9**-**-***4')

    complete_verify_step(user)

    # phone page
    expect(page).to have_content(t('idv.titles.session.phone'))
  end
end
