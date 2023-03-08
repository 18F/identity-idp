require_relative 'idv_step_helper'
require_relative 'doc_auth_helper'

module InPersonHelper
  include IdvStepHelper
  include DocAuthHelper

  GOOD_FIRST_NAME = Idp::Constants::MOCK_IDV_APPLICANT[:first_name]
  GOOD_LAST_NAME = Idp::Constants::MOCK_IDV_APPLICANT[:last_name]
  GOOD_DOB = Idp::Constants::MOCK_IDV_APPLICANT[:dob]
  GOOD_STATE_ID_JURISDICTION = Idp::Constants::MOCK_IDV_APPLICANT_FULL_STATE_ID_JURISDICTION
  GOOD_STATE_ID_NUMBER = Idp::Constants::MOCK_IDV_APPLICANT[:state_id_number]

  GOOD_ADDRESS1 = Idp::Constants::MOCK_IDV_APPLICANT[:address1]
  GOOD_ADDRESS2 = Idp::Constants::MOCK_IDV_APPLICANT[:address2]
  GOOD_CITY = Idp::Constants::MOCK_IDV_APPLICANT[:city]
  GOOD_ZIPCODE = Idp::Constants::MOCK_IDV_APPLICANT[:zipcode]
  GOOD_STATE = Idp::Constants::MOCK_IDV_APPLICANT_FULL_STATE

  def fill_out_state_id_form_ok
    fill_in t('in_person_proofing.form.state_id.first_name'), with: GOOD_FIRST_NAME
    fill_in t('in_person_proofing.form.state_id.last_name'), with: GOOD_LAST_NAME
    year, month, day = GOOD_DOB.split('-')
    fill_in t('components.memorable_date.month'), with: month
    fill_in t('components.memorable_date.day'), with: day
    fill_in t('components.memorable_date.year'), with: year
    select GOOD_STATE_ID_JURISDICTION,
           from: t('in_person_proofing.form.state_id.state_id_jurisdiction')
    fill_in t('in_person_proofing.form.state_id.state_id_number'), with: GOOD_STATE_ID_NUMBER
  end

  def fill_out_address_form_ok
    fill_in t('idv.form.address1'), with: GOOD_ADDRESS1
    fill_in t('idv.form.address2_optional'), with: GOOD_ADDRESS2
    fill_in t('idv.form.city'), with: GOOD_CITY
    fill_in t('idv.form.zipcode'), with: GOOD_ZIPCODE
    select GOOD_STATE, from: t('idv.form.state')
    choose t('in_person_proofing.form.address.same_address_choice_yes')
  end

  def begin_in_person_proofing(_user = nil)
    complete_doc_auth_steps_before_document_capture_step
    mock_doc_auth_attention_with_barcode
    attach_and_submit_images
    click_link t('in_person_proofing.body.cta.button')
  end

  def complete_in_person_proofing(user = nil)
    begin_in_person_proofing(user)

    # location page
    expect_in_person_step_indicator_current_step(t('step_indicator.flows.idv.find_a_post_office'))
    expect(page).to have_content(t('in_person_proofing.headings.po_search.location'))
    search_for_post_office
    bethesda_location = page.find_all('.location-collection-item')[1]
    bethesda_location.click_button(t('in_person_proofing.body.location.location_button'))

    # prepare page
    expect_in_person_step_indicator_current_step(t('step_indicator.flows.idv.find_a_post_office'))
    expect(page).to have_content(t('in_person_proofing.headings.prepare'))
    complete_prepare_step(user)

    # state ID page
    expect_in_person_step_indicator_current_step(t('step_indicator.flows.idv.verify_info'))
    expect(page).to have_content(t('in_person_proofing.headings.state_id'))
    complete_state_id_step(user)

    # address page
    expect_in_person_step_indicator_current_step(t('step_indicator.flows.idv.verify_info'))
    expect(page).to have_content(t('in_person_proofing.headings.address'))
    expect(page).to have_content(t('in_person_proofing.form.address.same_address'))
    complete_address_step(user)

    # ssn page
    expect_in_person_step_indicator_current_step(t('step_indicator.flows.idv.verify_info'))
    expect(page).to have_content(t('doc_auth.headings.ssn'))
    complete_ssn_step(user)

    # verify page
    expect_in_person_step_indicator_current_step(t('step_indicator.flows.idv.verify_info'))
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
    expect_in_person_step_indicator_current_step(
      t('step_indicator.flows.idv.verify_phone_or_address'),
    )
    expect(page).to have_content(t('idv.titles.session.phone'))
    fill_out_phone_form_ok(MfaContext.new(user).phone_configurations.first.phone)
    click_idv_send_security_code
    expect_in_person_step_indicator_current_step(
      t('step_indicator.flows.idv.verify_phone_or_address'),
    )

    expect_in_person_step_indicator_current_step(
      t('step_indicator.flows.idv.verify_phone_or_address'),
    )
    fill_in_code_with_last_phone_otp
    click_submit_default

    # password confirm page
    expect_in_person_step_indicator_current_step(t('step_indicator.flows.idv.secure_account'))
    expect(page).to have_content(t('idv.titles.session.review', app_name: APP_NAME))
    complete_review_step(user)

    # personal key page
    expect_in_person_step_indicator_current_step(t('step_indicator.flows.idv.secure_account'))
    expect(page).to have_content(t('titles.idv.personal_key'))
    deadline = nil
    freeze_time do
      acknowledge_and_confirm_personal_key
      deadline = (Time.zone.now + IdentityConfig.store.in_person_enrollment_validity_in_days.days).
        in_time_zone(Idv::InPerson::ReadyToVerifyPresenter::USPS_SERVER_TIMEZONE).
        strftime(t('time.formats.event_date'))
    end

    # ready to verify page
    expect_in_person_step_indicator_current_step(
      t('step_indicator.flows.idv.go_to_the_post_office'),
    )
    expect(page).to be_axe_clean.according_to :section508, :"best-practice", :wcag21aa
    enrollment_code = JSON.parse(
      UspsInPersonProofing::Mock::Fixtures.request_enroll_response,
    )['enrollmentCode']
    expect(page).to have_content(t('in_person_proofing.headings.barcode'))
    expect(page).to have_content(Idv::InPerson::EnrollmentCodeFormatter.format(enrollment_code))
    expect(page).to have_content(t('in_person_proofing.body.barcode.deadline', deadline: deadline))
    expect(page).to have_content('MILWAUKEE')
    expect(page).to have_content(
      "#{t('date.day_names')[6]}: #{t('in_person_proofing.body.barcode.retail_hours_closed')}",
    )

    enrollment_code
  end

  def search_for_post_office
    fill_in t('in_person_proofing.body.location.po_search.address_search_label'),
            with: GOOD_ADDRESS1
    click_button(t('in_person_proofing.body.location.po_search.search_button'))
    # Wait for page to load before selecting location
    expect(page).to have_css('.location-collection-item', wait: 10)
  end

  def complete_location_step(_user = nil)
    search_for_post_office
    first('.location-collection-item').
      click_button(t('in_person_proofing.body.location.location_button'))
  end

  def complete_prepare_step(_user = nil)
    # Wait for page to load before clicking continue
    expect(page).to have_content(
      t('in_person_proofing.headings.prepare'),
    )
    click_link t('forms.buttons.continue')
  end

  def complete_state_id_step(_user = nil)
    # Wait for page to load before attempting to fill out form
    expect(page).to have_current_path(idv_in_person_step_path(step: :state_id), wait: 10)
    fill_out_state_id_form_ok
    click_idv_continue
  end

  def complete_address_step(_user = nil)
    fill_out_address_form_ok
    click_idv_continue
  end

  def complete_ssn_step(_user = nil)
    fill_out_ssn_form_ok
    click_idv_continue
  end

  def complete_verify_step(_user = nil)
    click_idv_continue
  end

  def complete_all_in_person_proofing_steps(user = user_with_2fa)
    complete_location_step(user)
    complete_prepare_step(user)
    complete_state_id_step(user)
    complete_address_step(user)
    complete_ssn_step(user)
    complete_verify_step(user)
  end

  def expect_in_person_step_indicator_current_step(text)
    # Normally we're only concerned with the "current" step, but since some steps are shared between
    # flows, we also want to make sure that at least one of the in-person-specific steps exists in
    # the step indicator.
    expect(page).to have_css(
      '.step-indicator__step',
      text: t('step_indicator.flows.idv.find_a_post_office'),
    )

    expect_step_indicator_current_step(text)
  end

  def expect_in_person_gpo_step_indicator_current_step(text)
    # Ensure that GPO letter step is shown in the step indicator.
    expect(page).to have_css(
      '.step-indicator__step',
      text: t('step_indicator.flows.idv.get_a_letter'),
    )

    expect_in_person_step_indicator_current_step(text)
  end
end
