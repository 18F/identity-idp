require 'rails_helper'

RSpec.describe 'doc auth IPP state ID step', js: true do
  include IdvStepHelper
  include InPersonHelper

  before do
    allow(IdentityConfig.store).to receive(:in_person_proofing_enabled).and_return(true)
  end

  context 'when visiting state id for the first time' do
    it 'displays correct heading and button text', allow_browser_log: true do
      complete_steps_before_state_id_step

      expect(page).to have_content(t('forms.buttons.continue'))
      expect(page).to have_content(
        t(
          'in_person_proofing.headings.state_id_milestone_2',
        ).tr(' ', ' '),
      )
    end

    it 'allows the user to cancel and start over', allow_browser_log: true do
      complete_steps_before_state_id_step

      expect(page).not_to have_content('forms.buttons.back')

      click_link t('links.cancel')
      click_on t('idv.cancel.actions.start_over')
      expect(page).to have_current_path(idv_welcome_path)
    end

    it 'allows the user to cancel and return', allow_browser_log: true do
      complete_steps_before_state_id_step

      expect(page).not_to have_content('forms.buttons.back')

      click_link t('links.cancel')
      click_on t('idv.cancel.actions.keep_going')
      expect(page).to have_current_path(idv_in_person_step_path(step: :state_id), wait: 10)
    end

    it 'allows user to submit valid inputs on form', allow_browser_log: true do
      complete_steps_before_state_id_step
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

  context 'when updating by visiting state id from verify info pg' do
    # is this needed considering the verify_info_spec?
  end

  context 'Validation' do
    it 'validates zip code input', allow_browser_log: true do
      complete_steps_before_state_id_step

      fill_out_state_id_form_ok(same_address_as_id: true)
      # blank out the zip code field
      fill_in t('in_person_proofing.form.state_id.zipcode'), with: ''
      # try to enter invalid input into the zip code field
      fill_in t('in_person_proofing.form.state_id.zipcode'), with: 'invalid input'
      expect(page).to have_field(t('in_person_proofing.form.state_id.zipcode'), with: '')
      # enter valid characters, but invalid length
      fill_in t('in_person_proofing.form.state_id.zipcode'), with: '123'
      click_idv_continue
      expect(page).to have_css('.usa-error-message', text: t('idv.errors.pattern_mismatch.zipcode'))
      # enter a valid zip and make sure we can continue
      fill_in t('in_person_proofing.form.state_id.zipcode'), with: '123456789'
      expect(page).to have_field(t('in_person_proofing.form.state_id.zipcode'), with: '12345-6789')
      click_idv_continue
      expect(page).to have_current_path(idv_in_person_ssn_url)
    end
  end

  context 'State selection' do
    it 'shows address hint when user selects state that has a specific hint',
       allow_browser_log: true do
      complete_steps_before_state_id_step

      # state id page
      select 'Puerto Rico',
             from: t('in_person_proofing.form.state_id.identity_doc_address_state')

      expect(page).to have_content(I18n.t('in_person_proofing.form.state_id.address1_hint'))
      expect(page).to have_content(I18n.t('in_person_proofing.form.state_id.address2_hint'))

      # change state selection
      fill_out_state_id_form_ok(same_address_as_id: true)
      expect(page).not_to have_content(I18n.t('in_person_proofing.form.state_id.address1_hint'))
      expect(page).not_to have_content(I18n.t('in_person_proofing.form.state_id.address2_hint'))

      # re-select puerto rico
      select 'Puerto Rico',
             from: t('in_person_proofing.form.state_id.identity_doc_address_state')
      click_idv_continue

      # ssn page
      expect(page).to have_current_path(idv_in_person_ssn_url)
      complete_ssn_step

      # verify page
      expect(page).to have_current_path(idv_in_person_verify_info_path)
      expect(page).to have_text('PR')

      # update state ID
      click_button t('idv.buttons.change_state_id_label')

      expect(page).to have_content(t('in_person_proofing.headings.update_state_id'))
      expect(page).to have_content(I18n.t('in_person_proofing.form.state_id.address1_hint'))
      expect(page).to have_content(I18n.t('in_person_proofing.form.state_id.address2_hint'))
    end

    it 'shows id number hint when user selects issuing state that has a specific hint',
       allow_browser_log: true do
      complete_steps_before_state_id_step

      # expect default hint to be present
      expect(page).to have_content(t('in_person_proofing.form.state_id.state_id_number_hint'))

      select 'Texas',
             from: t('in_person_proofing.form.state_id.state_id_jurisdiction')
      expect(page).to have_content(t('in_person_proofing.form.state_id.state_id_number_texas_hint'))
      expect(page).not_to have_content(t('in_person_proofing.form.state_id.state_id_number_hint'))

      select 'Florida',
             from: t('in_person_proofing.form.state_id.state_id_jurisdiction')
      expect(page).not_to have_content(t('in_person_proofing.form.state_id.state_id_number_texas_hint'))
      expect(page).not_to have_content(t('in_person_proofing.form.state_id.state_id_number_hint'))
      expect(page).to have_content(t('in_person_proofing.form.state_id.state_id_number_florida_hint'))

      # select a state without a state specific hint
      select 'Ohio',
             from: t('in_person_proofing.form.state_id.state_id_jurisdiction')
      expect(page).to have_content(t('in_person_proofing.form.state_id.state_id_number_hint'))
      expect(page).not_to have_content(t('in_person_proofing.form.state_id.state_id_number_texas_hint'))
      expect(page).not_to have_content(t('in_person_proofing.form.state_id.state_id_number_florida_hint'))
    end
  end

  context 'transliteration' do
    before(:each) do
      allow(IdentityConfig.store).to receive(:usps_ipp_transliteration_enabled).
        and_return(true)
    end

    it 'shows validation errors',
       allow_browser_log: true do
      complete_steps_before_state_id_step

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

      # TODO: may want to update enums to use valid/invalid-> we can workshop this
      # re-fill state id form with good inputs
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

      expect(page).to have_current_path(idv_in_person_step_path(step: :address), wait: 10)
    end
  end
end
