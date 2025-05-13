require_relative 'idv_step_helper'
require_relative 'doc_auth_helper'

module InPersonHelper
  include IdvStepHelper
  include DocAuthHelper

  GOOD_FIRST_NAME = Idp::Constants::MOCK_IDV_APPLICANT[:first_name].freeze
  GOOD_LAST_NAME = Idp::Constants::MOCK_IDV_APPLICANT[:last_name].freeze
  # the date in the format '1938-10-06'
  GOOD_DOB = Idp::Constants::MOCK_IDV_APPLICANT[:dob].freeze
  # the date in the format 'October 6, 1938'
  GOOD_DOB_FORMATTED_EVENT = I18n.l(
    Date.parse(GOOD_DOB), format: I18n.t('time.formats.event_date')
  ).freeze
  GOOD_STATE_ID_JURISDICTION = Idp::Constants::MOCK_IDV_APPLICANT_FULL_STATE_ID_JURISDICTION
  GOOD_STATE_ID_NUMBER = Idp::Constants::MOCK_IDV_APPLICANT[:state_id_number].freeze

  GOOD_ADDRESS1 = Idp::Constants::MOCK_IDV_APPLICANT[:address1].freeze
  GOOD_ADDRESS2 = Idp::Constants::MOCK_IDV_APPLICANT[:address2].freeze
  GOOD_CITY = Idp::Constants::MOCK_IDV_APPLICANT[:city].freeze
  GOOD_ZIPCODE = Idp::Constants::MOCK_IDV_APPLICANT[:zipcode].freeze
  GOOD_STATE = Idp::Constants::MOCK_IDV_APPLICANT_FULL_STATE
  GOOD_IDENTITY_DOC_ADDRESS1 =
    Idp::Constants::MOCK_IDV_APPLICANT_STATE_ID_ADDRESS[:identity_doc_address1].freeze
  GOOD_IDENTITY_DOC_ADDRESS2 =
    Idp::Constants::MOCK_IDV_APPLICANT_STATE_ID_ADDRESS[:identity_doc_address2].freeze
  GOOD_IDENTITY_DOC_ADDRESS_STATE =
    Idp::Constants::MOCK_IDV_APPLICANT_FULL_IDENTITY_DOC_ADDRESS_STATE
  GOOD_IDENTITY_DOC_CITY =
    Idp::Constants::MOCK_IDV_APPLICANT_STATE_ID_ADDRESS[:identity_doc_city].freeze
  GOOD_IDENTITY_DOC_ZIPCODE =
    Idp::Constants::MOCK_IDV_APPLICANT_STATE_ID_ADDRESS[:identity_doc_zipcode].freeze

  GOOD_PASSPORT_NUMBER = Idp::Constants::MOCK_IPP_PASSPORT_APPLICANT[:passport_number].freeze
  GOOD_PASSPORT_EXPIRATION_DATE =
    Idp::Constants::MOCK_IPP_PASSPORT_APPLICANT[:passport_expiration_date].freeze

  def fill_out_state_id_form_ok(same_address_as_id: false, first_name: GOOD_FIRST_NAME)
    fill_in t('in_person_proofing.form.state_id.first_name'), with: first_name
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
    select GOOD_STATE,
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

  def begin_in_person_proofing_with_opt_in_ipp_enabled_and_opting_in
    complete_up_to_how_to_verify_step_for_opt_in_ipp(remote: false)
  end

  def begin_in_person_proofing_with_opt_in_ipp_enabled_and_opting_out
    complete_up_to_how_to_verify_step_for_opt_in_ipp(remote: true)
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

  # Fills in a memorable date component input
  #
  # @param [String] field_name Name of the form plus the component name. e.g. `test_form[test_dob]`
  # @param [String] date The date to enter into the input. `Format: YYYY-MM-DD`
  def fill_in_memorable_date(field_name, date)
    year, month, day = date.split('-')
    fill_in "#{field_name}[month]", with: month
    fill_in "#{field_name}[day]", with: day
    fill_in "#{field_name}[year]", with: year
  end

  def complete_location_step(_user = nil)
    search_for_post_office
    within first('.location-collection-item') do
      click_spinner_button_and_wait t('in_person_proofing.body.location.location_button')
    end

    # pause for the location list to disappear
    wait_for_content_to_disappear do
      expect(page).to have_no_css('.location-collection-item', wait: 1)
    end
  end

  def complete_prepare_step(_user = nil)
    expect(page).to(have_content(t('in_person_proofing.headings.prepare')))
    expect(page).to(have_content(t('in_person_proofing.body.prepare.verify_step_about')))
    expect_in_person_step_indicator_current_step(t('step_indicator.flows.idv.find_a_post_office'))
    click_on t('forms.buttons.continue')
  end

  def complete_state_id_controller(_user = nil, same_address_as_id: true,
                                   first_name: GOOD_FIRST_NAME)
    # Wait for page to load before attempting to fill out form
    expect(page).to have_current_path(idv_in_person_state_id_path, wait: 10)
    fill_out_state_id_form_ok(same_address_as_id: same_address_as_id, first_name:)
    click_idv_continue
    unless same_address_as_id
      expect(page).to have_current_path(idv_in_person_address_path, wait: 10)
      expect_in_person_step_indicator_current_step(t('step_indicator.flows.idv.verify_info'))
    end
  end

  def complete_address_step(_user = nil, same_address_as_id: true)
    fill_out_address_form_ok(same_address_as_id: same_address_as_id)
    click_idv_continue
  end

  def complete_ssn_step(_user = nil, tmx_status = nil)
    fill_out_ssn_form_ok
    select tmx_status.to_s, from: :mock_profiling_result unless tmx_status.nil?
    click_idv_continue
  end

  def complete_verify_step(_user = nil)
    click_idv_submit_default
  end

  def complete_steps_before_state_id_controller
    sign_in_and_2fa_user
    begin_in_person_proofing
    complete_prepare_step
    complete_location_step
    expect(page).to have_current_path(idv_in_person_state_id_path, wait: 10)
  end

  def complete_steps_before_info_verify(user = user_with_2fa)
    sign_in_and_2fa_user(user)
    begin_in_person_proofing(user)
    complete_prepare_step(user)
    complete_location_step(user)
    complete_state_id_controller(user)
    complete_ssn_step(user)
  end

  def complete_all_in_person_proofing_steps(user = user_with_2fa, tmx_status = nil,
                                            same_address_as_id: true)
    complete_prepare_step(user)
    complete_location_step(user)
    complete_state_id_controller(user, same_address_as_id: same_address_as_id)
    complete_address_step(user, same_address_as_id: same_address_as_id) unless same_address_as_id
    complete_ssn_step(user, tmx_status)
    complete_verify_step(user)
  end

  def complete_entire_ipp_flow(user = user_with_2fa, tmx_status = nil, same_address_as_id: true)
    sign_in_and_2fa_user(user)
    begin_in_person_proofing(user)
    complete_all_in_person_proofing_steps(user, tmx_status, same_address_as_id: same_address_as_id)
    click_idv_send_security_code
    fill_in_code_with_last_phone_otp
    click_submit_default
    complete_enter_password_step(user)
    acknowledge_and_confirm_personal_key
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

  def build_pii_before_state_id_update(same_address_as_id: 'true')
    pii_from_user[:same_address_as_id] = same_address_as_id
    pii_from_user[:identity_doc_address1] = identity_doc_address1
    pii_from_user[:identity_doc_address2] = identity_doc_address2
    pii_from_user[:identity_doc_city] = identity_doc_city
    pii_from_user[:identity_doc_address_state] = identity_doc_address_state
    pii_from_user[:identity_doc_zipcode] = identity_doc_zipcode
    if same_address_as_id == 'true'
      pii_from_user[:address1] = identity_doc_address1
      pii_from_user[:address2] = identity_doc_address2
      pii_from_user[:city] = identity_doc_city
      pii_from_user[:state] = identity_doc_address_state
      pii_from_user[:zipcode] = identity_doc_zipcode
    else
      pii_from_user[:address1] = address1
      pii_from_user[:address2] = address2
      pii_from_user[:city] = city
      pii_from_user[:state] = state
      pii_from_user[:zipcode] = zipcode
    end
  end

  def mark_in_person_enrollment_passed(user, document_type = :state_id)
    enrollment = user.in_person_enrollments.last
    expect(enrollment).to_not be_nil
    expect(enrollment.document_type&.to_sym).to eq(document_type)
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
      expect(page).to have_current_path(idv_in_person_state_id_path, wait: 10)

      complete_state_id_controller(user, same_address_as_id: same_address_as_id)
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
