require 'rails_helper'

RSpec.describe 'state id controller enabled', :js do
  include IdvStepHelper
  include InPersonHelper

  before do
    allow(IdentityConfig.store).to receive(:in_person_proofing_enabled).and_return(true)
  end

  context 'when visiting state id for the first time' do
    it 'displays correct heading and button text', allow_browser_log: true do
      complete_steps_before_state_id_controller

      expect(page).to have_content(t('forms.buttons.continue'))
      expect(page).to have_content(
        strip_nbsp(t('in_person_proofing.headings.state_id_milestone_2')),
      )
    end

    it 'allows user to submit valid inputs on form', allow_browser_log: true do
      complete_steps_before_state_id_controller
      fill_out_state_id_form_ok(same_address_as_id: true)
      click_idv_continue

      expect(page).to have_current_path(idv_in_person_ssn_url, wait: 10)
      complete_ssn_step

      expect_in_person_step_indicator_current_step(t('step_indicator.flows.idv.verify_info'))
      expect(page).to have_current_path(idv_in_person_verify_info_url)
      expect(page).to have_text(InPersonHelper::GOOD_FIRST_NAME)
      expect(page).to have_text(InPersonHelper::GOOD_LAST_NAME)
      expect(page).to have_text(InPersonHelper::GOOD_DOB_FORMATTED_EVENT)
      expect(page).to have_text(InPersonHelper::GOOD_STATE_ID_NUMBER)
      expect(page).to have_text(InPersonHelper::GOOD_IDENTITY_DOC_ADDRESS1)
      expect(page).to have_text(InPersonHelper::GOOD_IDENTITY_DOC_ADDRESS2)
      expect(page).to have_text(InPersonHelper::GOOD_IDENTITY_DOC_CITY)
      expect(page).to have_text(InPersonHelper::GOOD_IDENTITY_DOC_ZIPCODE)
    end
  end

  context 'validation' do
    it 'validates zip code input', allow_browser_log: true do
      complete_steps_before_state_id_controller

      fill_out_state_id_form_ok(same_address_as_id: true)
      fill_in t('in_person_proofing.form.state_id.zipcode'), with: ''
      fill_in t('in_person_proofing.form.state_id.zipcode'), with: 'invalid input'
      expect(page).to have_field(t('in_person_proofing.form.state_id.zipcode'), with: '')

      # enter valid characters, but invalid length
      fill_in t('in_person_proofing.form.state_id.zipcode'), with: '123'
      click_idv_continue
      expect(page).to have_css(
        '.ads-input__error--visible',
        text: t('idv.errors.pattern_mismatch.zipcode'),
      )

      # enter a valid zip and make sure we can continue
      fill_in t('in_person_proofing.form.state_id.zipcode'), with: '123456789'
      expect(page).to have_field(
        t('in_person_proofing.form.state_id.zipcode'),
        with: '12345-6789',
      )
      click_idv_continue
      expect(page).to have_current_path(idv_in_person_ssn_url)
    end

    it 'shows error for dob under minimum age', allow_browser_log: true do
      complete_steps_before_state_id_controller

      buffer_to_avoid_test_flakiness = 2.days

      less_than_13_years_ago = Time.zone.now - (13.years - buffer_to_avoid_test_flakiness)
      dob = [
        less_than_13_years_ago.year,
        format('%02d', less_than_13_years_ago.month),
        format('%02d', less_than_13_years_ago.day),
      ].join('-')

      fill_in t('in_person_proofing.form.state_id.dob'), with: dob

      click_idv_continue
      expect(page).to have_content(
        t(
          'in_person_proofing.form.state_id.memorable_date.errors.date_of_birth.range_min_age',
          app_name: APP_NAME,
        ),
      )

      thirteenish_years_ago = Time.zone.now - (13.years + buffer_to_avoid_test_flakiness)
      dob = [
        thirteenish_years_ago.year,
        format('%02d', thirteenish_years_ago.month),
        format('%02d', thirteenish_years_ago.day),
      ].join('-')

      fill_in t('in_person_proofing.form.state_id.dob'), with: dob

      click_idv_continue
      expect(page).not_to have_content(
        t(
          'in_person_proofing.form.state_id.memorable_date.errors.date_of_birth.range_min_age',
          app_name: APP_NAME,
        ),
      )
    end

    it 'shows error for an expired ID', allow_browser_log: true do
      complete_steps_before_state_id_controller

      yesterday = Time.zone.now - 1.day
      exp = [
        yesterday.year,
        format('%02d', yesterday.month),
        format('%02d', yesterday.day),
      ].join('-')

      fill_in t('in_person_proofing.form.state_id.expiration_date'), with: exp

      click_idv_continue

      expect(page).to have_content(
        t(
          'in_person_proofing.form.state_id.memorable_date.errors.expiration_date.expired',
          app_name: APP_NAME,
        ),
      )

      two_days_from_today = Time.zone.now + 2.days
      exp = [
        two_days_from_today.year,
        format('%02d', two_days_from_today.month),
        format('%02d', two_days_from_today.day),
      ].join('-')

      fill_in t('in_person_proofing.form.state_id.expiration_date'), with: exp

      click_idv_continue
      expect(page).not_to have_content(
        t(
          'in_person_proofing.form.state_id.memorable_date.errors.expiration_date.expired',
          app_name: APP_NAME,
        ),
      )
    end
  end

  context 'transliterable validation' do
    it 'shows validation errors',
       allow_browser_log: true do
      complete_steps_before_state_id_controller

      fill_out_state_id_form_ok
      fill_in t('in_person_proofing.form.state_id.first_name'), with: 'T0mmy "Lee"'
      fill_in t('in_person_proofing.form.state_id.last_name'), with: 'Джейкоб'
      fill_in t('in_person_proofing.form.state_id.address1'), with: '#1 $treet'
      fill_in t('in_person_proofing.form.state_id.address2'), with: 'Gr@nd Lañe^'
      fill_in t('in_person_proofing.form.state_id.city'), with: 'N3w C!ty'
      click_idv_continue

      expect(page).to have_content(
        I18n.t(
          'in_person_proofing.form.state_id.errors.unsupported_chars',
          char_list: '", 0',
        ),
      )

      expect(page).to have_content(
        I18n.t(
          'in_person_proofing.form.state_id.errors.unsupported_chars',
          char_list: 'Д, б, е, ж, й, к, о',
        ),
      )

      expect(page).to have_content(
        I18n.t(
          'in_person_proofing.form.state_id.errors.unsupported_chars',
          char_list: '$',
        ),
      )

      expect(page).to have_content(
        I18n.t(
          'in_person_proofing.form.state_id.errors.unsupported_chars',
          char_list: '@, ^',
        ),
      )

      expect(page).to have_content(
        I18n.t(
          'in_person_proofing.form.state_id.errors.unsupported_chars',
          char_list: '!, 3',
        ),
      )

      fill_in t('in_person_proofing.form.state_id.first_name'),
              with: InPersonHelper::GOOD_FIRST_NAME
      fill_in t('in_person_proofing.form.state_id.last_name'),
              with: InPersonHelper::GOOD_LAST_NAME
      fill_in t('in_person_proofing.form.state_id.address1'),
              with: InPersonHelper::GOOD_IDENTITY_DOC_ADDRESS1
      fill_in t('in_person_proofing.form.state_id.address2'),
              with: InPersonHelper::GOOD_IDENTITY_DOC_ADDRESS2
      fill_in t('in_person_proofing.form.state_id.city'),
              with: InPersonHelper::GOOD_IDENTITY_DOC_CITY
      click_idv_continue

      expect(page).to have_current_path(idv_in_person_address_url, wait: 10)
    end
  end

  context 'state selection' do
    it 'submits when Puerto Rico is selected as address state',
       allow_browser_log: true do
      complete_steps_before_state_id_controller

      fill_out_state_id_form_ok(same_address_as_id: true)
      select 'Puerto Rico',
             from: t('in_person_proofing.form.state_id.identity_doc_address_state')
      click_idv_continue

      expect(page).to have_current_path(idv_in_person_ssn_url)
      complete_ssn_step

      expect(page).to have_current_path(idv_in_person_verify_info_path)
      expect(page).to have_text('PR')
    end
  end
end
