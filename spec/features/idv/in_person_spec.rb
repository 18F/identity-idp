require 'rails_helper'

RSpec.describe 'In Person Proofing' do
  include DocAuthHelper
  include IdvHelper
  include InPersonHelper

  before do
    allow(IdentityConfig.store).to receive(:in_person_proofing_enabled).and_return(true)
  end

  it 'works for a happy path', js: true, allow_browser_log: true do
    user = sign_in_and_2fa_user

    # welcome step
    visit idv_doc_auth_welcome_step # only thing used from DocAuthHelper
    click_idv_continue

    # information step
    find('label', text: t('doc_auth.instructions.consent', app_name: APP_NAME)).click
    click_idv_continue

    # upload documents step
    click_on t('doc_auth.info.upload_computer_link')
    attach_images_that_fail
    click_submit_default
    expect(page).to have_content(t('idv.troubleshooting.options.verify_in_person'), wait: 60)

    # start the IPP flow
    find_button(t('idv.troubleshooting.options.verify_in_person')).click

    # location page
    expect(page).to have_content(t('in_person_proofing.headings.location'))
    click_idv_continue

    # prepare page
    expect(page).to have_content(t('in_person_proofing.headings.prepare'))
    click_link t('forms.buttons.continue')

    # state ID page
    expect(page).to have_content(t('in_person_proofing.headings.state_id'))
    fill_out_state_id_form_ok
    click_idv_continue

    # address page
    expect(page).to have_content(t('in_person_proofing.headings.address'))
    fill_out_address_form_ok
    click_idv_continue

    # ssn page
    expect(page).to have_content(t('doc_auth.headings.ssn'))
    fill_out_ssn_form_ok
    click_idv_continue

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
    click_idv_continue

    # phone page
    expect(page).to have_content(t('idv.titles.session.phone'))
    fill_out_phone_form_mfa_phone(user)
    click_idv_continue
    verify_phone_otp

    # password confirm page
    expect(page).to have_content(
      t('idv.titles.session.review', app_name: APP_NAME),
    )
    fill_in t('idv.form.password'), with: Features::SessionHelper::VALID_PASSWORD
    click_idv_continue

    # personal key page
    expect(page).to have_content(t('titles.idv.personal_key'))
    deadline = nil
    freeze_time do
      acknowledge_and_confirm_personal_key
      deadline = (Time.zone.now + IdentityConfig.store.in_person_enrollment_validity_in_days.days).
        strftime(t('time.formats.event_date'))
    end

    # ready to verify page
    enrollment_code = JSON.parse(UspsIppFixtures.request_enrollment_code_response)['enrollmentCode']
    expect(page).to have_content(t('in_person_proofing.headings.barcode'))
    expect(page).to have_content(Idv::InPerson::EnrollmentCodeFormatter.format(enrollment_code))
    expect(page).to have_content(t('in_person_proofing.body.barcode.deadline', deadline: deadline))
  end

  def attach_images_that_fail
    Tempfile.create(['ia2_mock', '.yml']) do |yml_file|
      yml_file.rewind
      yml_file.puts <<~YAML
        failed_alerts:
          - name: Document Classification
            result: Attention
      YAML
      yml_file.close

      attach_file t('doc_auth.headings.document_capture_front'), yml_file.path
      attach_file t('doc_auth.headings.document_capture_back'), yml_file.path
    end
  end
end
