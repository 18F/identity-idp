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

  def fill_out_state_id_form_ok(double_address_verification: false, same_address_as_id: false)
    fill_in t('in_person_proofing.form.state_id.first_name'), with: GOOD_FIRST_NAME
    fill_in t('in_person_proofing.form.state_id.last_name'), with: GOOD_LAST_NAME
    year, month, day = GOOD_DOB.split('-')
    fill_in t('components.memorable_date.month'), with: month
    fill_in t('components.memorable_date.day'), with: day
    fill_in t('components.memorable_date.year'), with: year
    select GOOD_STATE_ID_JURISDICTION,
           from: t('in_person_proofing.form.state_id.state_id_jurisdiction')
    fill_in t('in_person_proofing.form.state_id.state_id_number'), with: GOOD_STATE_ID_NUMBER

    if double_address_verification
      fill_in t('in_person_proofing.form.state_id.address1'), with: GOOD_IDENTITY_DOC_ADDRESS1
      fill_in t('in_person_proofing.form.state_id.address2'), with: GOOD_IDENTITY_DOC_ADDRESS2
      fill_in t('in_person_proofing.form.state_id.city'), with: GOOD_IDENTITY_DOC_CITY
      fill_in t('in_person_proofing.form.state_id.zipcode'), with: GOOD_IDENTITY_DOC_ZIPCODE
      if same_address_as_id
        select GOOD_IDENTITY_DOC_ADDRESS_STATE,
               from: t('in_person_proofing.form.state_id.identity_doc_address_state')
        choose t('in_person_proofing.form.state_id.same_address_as_id_yes')
      else
        select GOOD_STATE, from: t('in_person_proofing.form.state_id.identity_doc_address_state')
        choose t('in_person_proofing.form.state_id.same_address_as_id_no')
      end
    end
  end

  def fill_out_address_form_ok(double_address_verification: false, same_address_as_id: false)
    fill_in t('idv.form.address1'),
            with: same_address_as_id ? GOOD_IDENTITY_DOC_ADDRESS1 : GOOD_ADDRESS1
    fill_in t('idv.form.address2_optional'), with: GOOD_ADDRESS2 unless double_address_verification
    fill_in t('idv.form.address2'),
            with: same_address_as_id ? GOOD_IDENTITY_DOC_ADDRESS2 : GOOD_ADDRESS2
    fill_in t('idv.form.city'), with: same_address_as_id ? GOOD_IDENTITY_DOC_CITY : GOOD_CITY
    fill_in t('idv.form.zipcode'),
            with: same_address_as_id ? GOOD_IDENTITY_DOC_ZIPCODE : GOOD_ZIPCODE
    if same_address_as_id
      select GOOD_IDENTITY_DOC_ADDRESS_STATE, from: t('idv.form.state')
    else
      select GOOD_STATE, from: t('idv.form.state')
    end

    unless double_address_verification
      choose t('in_person_proofing.form.address.same_address_choice_yes')
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
    fill_in t('in_person_proofing.body.location.po_search.address_search_label'),
            with: GOOD_ADDRESS1
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

  def complete_state_id_step(_user = nil, same_address_as_id: true,
                             double_address_verification: false)
    # Wait for page to load before attempting to fill out form
    expect(page).to have_current_path(idv_in_person_step_path(step: :state_id), wait: 10)
    fill_out_state_id_form_ok(
      double_address_verification: double_address_verification,
      same_address_as_id: same_address_as_id,
    )
    click_idv_continue
    unless double_address_verification && same_address_as_id
      expect(page).to have_current_path(idv_in_person_step_path(step: :address), wait: 10)
      expect_in_person_step_indicator_current_step(t('step_indicator.flows.idv.verify_info'))
    end
  end

  def complete_address_step(_user = nil, double_address_verification: false)
    fill_out_address_form_ok(double_address_verification: double_address_verification)
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
    complete_prepare_step(user)
    complete_location_step(user)
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
end
