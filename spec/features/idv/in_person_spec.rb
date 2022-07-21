require 'rails_helper'

RSpec.describe 'In Person Proofing', js: true do
  include IdvStepHelper
  include InPersonHelper

  before do
    allow(IdentityConfig.store).to receive(:in_person_proofing_enabled).and_return(true)
    allow(IdentityConfig.store).to receive(:idv_api_enabled_steps).and_return(
      ['password_confirm',
       'personal_key', 'personal_key_confirm'],
    )
  end

  it 'works for a happy path', allow_browser_log: true do
    user = user_with_2fa

    begin_in_person_proofing(user)

    # location page
    expect(page).to have_content(t('in_person_proofing.headings.location'))
    complete_location_step(user)

    # prepare page
    expect(page).to have_content(t('in_person_proofing.headings.prepare'))
    complete_prepare_step(user)

    # state ID page
    expect(page).to have_content(t('in_person_proofing.headings.state_id'))
    complete_state_id_step(user)

    # address page
    expect(page).to have_content(t('in_person_proofing.headings.address'))
    complete_address_step(user)

    # ssn page
    expect(page).to have_content(t('doc_auth.headings.ssn'))
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
    click_button t('forms.buttons.submit.update')
    expect(page).to have_content(t('headings.verify'))

    # click update address button
    click_button t('idv.buttons.change_address_label')
    expect(page).to have_content(t('in_person_proofing.headings.update_address'))
    click_button t('forms.buttons.submit.update')
    expect(page).to have_content(t('headings.verify'))

    # click update ssn button
    click_button t('idv.buttons.change_ssn_label')
    expect(page).to have_content(t('doc_auth.headings.ssn_update'))
    fill_out_ssn_form_ok
    click_button t('forms.buttons.submit.update')
    expect(page).to have_content(t('headings.verify'))
    complete_verify_step(user)

    # phone page
    expect(page).to have_content(t('idv.titles.session.phone'))
    complete_phone_step(user)

    # password confirm page
    expect(page).to have_content(t('idv.titles.session.review', app_name: APP_NAME))
    complete_review_step(user)

    # personal key page
    expect(page).to have_content(t('titles.idv.personal_key'))
    deadline = nil
    freeze_time do
      acknowledge_and_confirm_personal_key
      deadline = (Time.zone.now + IdentityConfig.store.in_person_enrollment_validity_in_days.days).
        in_time_zone(Idv::InPerson::ReadyToVerifyPresenter::USPS_SERVER_TIMEZONE).
        strftime(t('time.formats.event_date'))
    end

    # ready to verify page
    enrollment_code = JSON.parse(UspsIppFixtures.request_enroll_response)['enrollmentCode']
    expect(page).to have_content(t('in_person_proofing.headings.barcode'))
    expect(page).to have_content(Idv::InPerson::EnrollmentCodeFormatter.format(enrollment_code))
    expect(page).to have_content(t('in_person_proofing.body.barcode.deadline', deadline: deadline))
  end

  context 'verify address by mail (GPO letter)' do
    it 'requires address verification before showing instructions', allow_browser_log: true do
      begin_in_person_proofing
      complete_all_in_person_proofing_steps
      click_on t('idv.troubleshooting.options.verify_by_mail')
      click_on t('idv.buttons.mail.send')
      complete_review_step
      acknowledge_and_confirm_personal_key

      expect(page).to have_content(t('idv.titles.come_back_later'))
      expect(page).to have_current_path(idv_come_back_later_path)

      # WILLFIX: After LG-6897, assert that "Ready to Verify" content is shown after code entry.
    end
  end
end
