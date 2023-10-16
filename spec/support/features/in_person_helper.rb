require_relative 'idv_step_helper'
require_relative 'doc_auth_helper'

module InPersonHelper
  include IdvStepHelper
  include DocAuthHelper

  GOOD_FIRST_NAME = Idp::Constants::MOCK_IDV_APPLICANT[:first_name]
  GOOD_LAST_NAME = Idp::Constants::MOCK_IDV_APPLICANT[:last_name]
  # the date in the format '1938-10-06'
  GOOD_DOB = Idp::Constants::MOCK_IDV_APPLICANT[:dob]
  # the date in the format 'October 6, 1938'
  GOOD_DOB_FORMATTED_EVENT = I18n.l(
    Date.parse(GOOD_DOB), format: I18n.t('time.formats.event_date')
  )
  GOOD_STATE_ID_JURISDICTION = Idp::Constants::MOCK_IDV_APPLICANT_FULL_STATE_ID_JURISDICTION
  GOOD_STATE_ID_NUMBER = Idp::Constants::MOCK_IDV_APPLICANT[:state_id_number]

  GOOD_ADDRESS1 = Idp::Constants::MOCK_IDV_APPLICANT[:address1]
  GOOD_ADDRESS2 = Idp::Constants::MOCK_IDV_APPLICANT[:address2]
  GOOD_CITY = Idp::Constants::MOCK_IDV_APPLICANT[:city]
  GOOD_ZIPCODE = Idp::Constants::MOCK_IDV_APPLICANT[:zipcode]
  GOOD_STATE = Idp::Constants::MOCK_IDV_APPLICANT_FULL_STATE
  GOOD_IDENTITY_DOC_ADDRESS1 =
    Idp::Constants::MOCK_IDV_APPLICANT_STATE_ID_ADDRESS[:identity_doc_address1]
  GOOD_IDENTITY_DOC_ADDRESS2 =
    Idp::Constants::MOCK_IDV_APPLICANT_STATE_ID_ADDRESS[:identity_doc_address2]
  GOOD_IDENTITY_DOC_ADDRESS_STATE =
    Idp::Constants::MOCK_IDV_APPLICANT_FULL_IDENTITY_DOC_ADDRESS_STATE
  GOOD_IDENTITY_DOC_CITY = Idp::Constants::MOCK_IDV_APPLICANT_STATE_ID_ADDRESS[:identity_doc_city]
  GOOD_IDENTITY_DOC_ZIPCODE =
    Idp::Constants::MOCK_IDV_APPLICANT_STATE_ID_ADDRESS[:identity_doc_zipcode]

  def fill_out_state_id_form_ok(same_address_as_id: false)
    fill_in t('in_person_proofing.form.state_id.first_name'), with: GOOD_FIRST_NAME
    fill_in t('in_person_proofing.form.state_id.last_name'), with: GOOD_LAST_NAME
    year, month, day = GOOD_DOB.split('-')
    fill_in t('components.memorable_date.month'), with: month
    fill_in t('components.memorable_date.day'), with: day
    fill_in t('components.memorable_date.year'), with: year
    select GOOD_STATE_ID_JURISDICTION,
           from: t('in_person_proofing.form.state_id.state_id_jurisdiction')
    fill_in t('in_person_proofing.form.state_id.state_id_number'), with: GOOD_STATE_ID_NUMBER

    fill_in t('in_person_proofing.form.state_id.address1'), with: GOOD_IDENTITY_DOC_ADDRESS1
    fill_in t('in_person_proofing.form.state_id.address2'), with: GOOD_IDENTITY_DOC_ADDRESS2
    fill_in t('in_person_proofing.form.state_id.city'), with: GOOD_IDENTITY_DOC_CITY
    fill_in t('in_person_proofing.form.state_id.zipcode'), with: GOOD_IDENTITY_DOC_ZIPCODE
    select GOOD_STATE_ID_JURISDICTION,
           from: t('in_person_proofing.form.state_id.identity_doc_address_state')
    if same_address_as_id
      choose t('in_person_proofing.form.state_id.same_address_as_id_yes')
    else
      choose t('in_person_proofing.form.state_id.same_address_as_id_no')
    end
  end

  def fill_out_address_form_ok(same_address_as_id: false)
    fill_in t('idv.form.address1'),
            with: same_address_as_id ? GOOD_IDENTITY_DOC_ADDRESS1 : GOOD_ADDRESS1
    fill_in t('idv.form.address2'),
            with: same_address_as_id ? GOOD_IDENTITY_DOC_ADDRESS2 : GOOD_ADDRESS2
    fill_in t('idv.form.city'), with: same_address_as_id ? GOOD_IDENTITY_DOC_CITY : GOOD_CITY
    fill_in t('idv.form.zipcode'),
            with: same_address_as_id ? GOOD_IDENTITY_DOC_ZIPCODE : GOOD_ZIPCODE
    if same_address_as_id
      select GOOD_STATE_ID_JURISDICTION, from: t('idv.form.state')
    else
      select GOOD_STATE, from: t('idv.form.state')
    end
  end

  def begin_in_person_proofing(_user = nil)
    complete_doc_auth_steps_before_document_capture_step
    mock_doc_auth_attention_with_barcode
    attach_and_submit_images
    click_button t('in_person_proofing.body.cta.button')
  end

  def search_for_post_office
    expect(page).to(have_content(t('in_person_proofing.headings.po_search.location')))
    expect(page).to(have_content(t('in_person_proofing.body.location.po_search.po_search_about')))
    expect_in_person_step_indicator_current_step(t('step_indicator.flows.idv.find_a_post_office'))
    fill_in t('in_person_proofing.body.location.po_search.address_label'),
            with: GOOD_ADDRESS1
    fill_in t('in_person_proofing.body.location.po_search.city_label'),
            with: GOOD_CITY
    select GOOD_STATE, from: t('in_person_proofing.form.state_id.identity_doc_address_state')
    fill_in t('in_person_proofing.body.location.po_search.zipcode_label'),
            with: GOOD_ZIPCODE
    click_spinner_button_and_wait(t('in_person_proofing.body.location.po_search.search_button'))
    expect(page).to have_css('.location-collection-item')
  end

  def complete_location_step(_user = nil)
    search_for_post_office
    within first('.location-collection-item') do
      click_spinner_button_and_wait t('in_person_proofing.body.location.location_button')
    end

    # pause for the location list to disappear
    begin
      expect(page).to have_no_css('.location-collection-item')
    rescue Selenium::WebDriver::Error::StaleElementReferenceError
      # A StaleElementReferenceError means that the context the element
      # was in has disappeared, which means the element is gone too.
    end
  end

  def complete_prepare_step(_user = nil)
    expect(page).to(have_content(t('in_person_proofing.headings.prepare')))
    expect(page).to(have_content(t('in_person_proofing.body.prepare.verify_step_about')))
    expect_in_person_step_indicator_current_step(t('step_indicator.flows.idv.find_a_post_office'))
    click_on t('forms.buttons.continue')
  end

  def complete_state_id_step(_user = nil, same_address_as_id: true)
    # Wait for page to load before attempting to fill out form
    expect(page).to have_current_path(idv_in_person_step_path(step: :state_id), wait: 10)
    fill_out_state_id_form_ok(same_address_as_id: same_address_as_id)
    click_idv_continue
    unless same_address_as_id
      expect(page).to have_current_path(idv_in_person_step_path(step: :address), wait: 10)
      expect_in_person_step_indicator_current_step(t('step_indicator.flows.idv.verify_info'))
    end
  end

  def complete_address_step(_user = nil, same_address_as_id: true)
    fill_out_address_form_ok(same_address_as_id: same_address_as_id)
    click_idv_continue
  end

  def complete_ssn_step(_user = nil)
    fill_out_ssn_form_ok
    click_idv_continue
  end

  def complete_verify_step(_user = nil)
    click_idv_continue
  end

  def complete_all_in_person_proofing_steps(user = user_with_2fa, same_address_as_id: true)
    complete_prepare_step(user)
    complete_location_step(user)
    complete_state_id_step(user, same_address_as_id: same_address_as_id)
    complete_address_step(user, same_address_as_id: same_address_as_id) unless same_address_as_id
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

  def make_pii(same_address_as_id: 'true')
    pii_from_user[:same_address_as_id] = same_address_as_id
    pii_from_user[:identity_doc_address1] = identity_doc_address1
    pii_from_user[:identity_doc_address2] = identity_doc_address2
    pii_from_user[:identity_doc_city] = identity_doc_city
    pii_from_user[:identity_doc_address_state] = identity_doc_address_state
    pii_from_user[:identity_doc_zipcode] = identity_doc_zipcode
    pii_from_user[:address1] = address1
    pii_from_user[:address2] = address2
    pii_from_user[:city] = city
    pii_from_user[:state] = state
    pii_from_user[:zipcode] = zipcode
  end

  def mark_in_person_enrollment_passed(user)
    enrollment = user.in_person_enrollments.last
    expect(enrollment).to_not be_nil
    enrollment.profile.activate_after_passing_in_person
    enrollment.update(status: :passed)
  end

  def perform_mobile_hybrid_steps
    perform_in_browser(:mobile) do
      # doc auth page
      visit @sms_link
      mock_doc_auth_attention_with_barcode
      attach_and_submit_images

      # error page
      click_button t('in_person_proofing.body.cta.button')
      # prepare page
      expect(page).to(have_content(t('in_person_proofing.body.prepare.verify_step_about')))
      click_idv_continue
      # location page
      expect(page).to have_content(t('in_person_proofing.headings.po_search.location'))
      complete_location_step

      # switch back page
      expect(page).to have_content(t('in_person_proofing.headings.switch_back'))
    end
  end

  def perform_desktop_hybrid_steps(user = user_with_2fa, same_address_as_id: true)
    perform_in_browser(:desktop) do
      expect(page).to have_current_path(idv_in_person_step_path(step: :state_id), wait: 10)

      complete_state_id_step(user, same_address_as_id: same_address_as_id)
      complete_address_step(user, same_address_as_id: same_address_as_id) unless same_address_as_id
      complete_ssn_step(user)
      complete_verify_step(user)
      complete_phone_step(user)
      complete_enter_password_step(user)
      acknowledge_and_confirm_personal_key

      expect(page).to have_content('MILWAUKEE')
    end
  end
end
