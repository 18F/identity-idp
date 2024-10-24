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
        strip_nbsp(
          t(
            'in_person_proofing.headings.state_id_milestone_2',
          ),
        ),
      )
    end

    it 'allows the user to cancel and start over', allow_browser_log: true do
      complete_steps_before_state_id_controller

      expect(page).not_to have_content('forms.buttons.back')

      click_link t('links.cancel')
      click_on t('idv.cancel.actions.start_over')
      expect(page).to have_current_path(idv_welcome_path)
    end

    it 'allows the user to cancel and return', allow_browser_log: true do
      complete_steps_before_state_id_controller

      expect(page).not_to have_content('forms.buttons.back')

      click_link t('links.cancel')
      click_on t('idv.cancel.actions.keep_going')
      expect(page).to have_current_path(idv_in_person_state_id_path, wait: 10)
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

  context 'updating state id page' do
    it 'has form fields that are pre-populated', allow_browser_log: true do
      complete_steps_before_state_id_controller

      fill_out_state_id_form_ok(same_address_as_id: true)
      click_idv_continue
      expect(page).to have_current_path(idv_in_person_ssn_url, wait: 10)
      complete_ssn_step
      expect(page).to have_current_path(idv_in_person_verify_info_url, wait: 10)
      click_link t('idv.buttons.change_state_id_label')

      # state id page has fields that are pre-populated
      expect(page).to have_current_path(idv_in_person_state_id_path, wait: 10)
      expect(page).to have_content(t('in_person_proofing.headings.update_state_id'))
      expect(page).to have_field(
        t('in_person_proofing.form.state_id.first_name'),
        with: InPersonHelper::GOOD_FIRST_NAME,
      )
      expect(page).to have_field(
        t('in_person_proofing.form.state_id.last_name'),
        with: InPersonHelper::GOOD_LAST_NAME,
      )
      expect(page).to have_field(t('components.memorable_date.month'), with: '10')
      expect(page).to have_field(t('components.memorable_date.day'), with: '6')
      expect(page).to have_field(t('components.memorable_date.year'), with: '1938')
      expect(page).to have_field(
        t('in_person_proofing.form.state_id.state_id_jurisdiction'),
        with: Idp::Constants::MOCK_IDV_APPLICANT[:state_id_jurisdiction],
      )
      expect(page).to have_field(
        t('in_person_proofing.form.state_id.state_id_number'),
        with: InPersonHelper::GOOD_STATE_ID_NUMBER,
      )
      expect(page).to have_field(
        t('in_person_proofing.form.state_id.address1'),
        with: InPersonHelper::GOOD_IDENTITY_DOC_ADDRESS1,
      )
      expect(page).to have_field(
        t('in_person_proofing.form.state_id.address2'),
        with: InPersonHelper::GOOD_IDENTITY_DOC_ADDRESS2,
      )
      expect(page).to have_field(
        t('in_person_proofing.form.state_id.city'),
        with: InPersonHelper::GOOD_IDENTITY_DOC_CITY,
      )
      expect(page).to have_field(
        t('in_person_proofing.form.state_id.zipcode'),
        with: InPersonHelper::GOOD_IDENTITY_DOC_ZIPCODE,
      )
      expect(page).to have_field(
        t('in_person_proofing.form.state_id.identity_doc_address_state'),
        with: Idp::Constants::MOCK_IDV_APPLICANT[:state_id_jurisdiction],
      )
      expect(page).to have_checked_field(
        t('in_person_proofing.form.state_id.same_address_as_id_yes'),
        visible: false,
      )
    end

    context 'same address as id',
            allow_browser_log: true do
      let(:user) { user_with_2fa }

      before(:each) do
        sign_in_and_2fa_user(user)
        begin_in_person_proofing(user)
        complete_prepare_step(user)
        complete_location_step(user)
      end

      it 'does not update their previous selection of "Yes,
        I live at the address on my state-issued ID"' do
        complete_state_id_controller(user, same_address_as_id: true)
        # skip address step
        complete_ssn_step(user)
        # expect to be on verify page
        expect(page).to have_content(t('headings.verify'))
        expect(page).to have_current_path(idv_in_person_verify_info_path)
        # click update state ID button on the verify page
        click_link t('idv.buttons.change_state_id_label')
        # expect to be on the state ID page
        expect(page).to have_content(t('in_person_proofing.headings.update_state_id'))
        # change address
        fill_in t('in_person_proofing.form.state_id.address1'), with: ''
        fill_in t('in_person_proofing.form.state_id.address1'), with: 'test update address'
        click_button t('forms.buttons.submit.update')
        # expect to be back on verify page
        expect(page).to have_content(t('headings.verify'))
        expect(page).to have_current_path(idv_in_person_verify_info_path)
        expect(page).to have_content(t('headings.verify'))
        # expect to see state ID address update on verify twice
        expect(page).to have_text('test update address').twice # for state id addr and addr update
        # click update state id address
        click_link t('idv.buttons.change_state_id_label')
        # expect to be on the state ID page
        expect(page).to have_content(t('in_person_proofing.headings.update_state_id'))
        # expect "Yes, I live at a different address" is checked"
        expect(page).to have_checked_field(
          t('in_person_proofing.form.state_id.same_address_as_id_yes'),
          visible: false,
        )
      end

      it 'does not update their previous selection of "No, I live at a different address"' do
        complete_state_id_controller(user, same_address_as_id: false)
        # expect to be on address page
        expect(page).to have_content(t('in_person_proofing.headings.address'))
        # complete address step
        complete_address_step(user)
        complete_ssn_step(user)
        # expect to be back on verify page
        expect(page).to have_content(t('headings.verify'))
        expect(page).to have_current_path(idv_in_person_verify_info_path)
        # click update state ID button on the verify page
        click_link t('idv.buttons.change_state_id_label')
        # expect to be on the state ID page
        expect(page).to have_content(t('in_person_proofing.headings.update_state_id'))
        # change address
        fill_in t('in_person_proofing.form.state_id.address1'), with: ''
        fill_in t('in_person_proofing.form.state_id.address1'), with: 'test update address'
        click_button t('forms.buttons.submit.update')
        # expect to be back on verify page
        expect(page).to have_content(t('headings.verify'))
        expect(page).to have_current_path(idv_in_person_verify_info_path)
        expect(page).to have_content(t('headings.verify'))
        # expect to see state ID address update on verify
        expect(page).to have_text('test update address').once # only state id address update
        # click update state id address
        click_link t('idv.buttons.change_state_id_label')
        # expect to be on the state ID page
        expect(page).to have_content(t('in_person_proofing.headings.update_state_id'))
        expect(page).to have_checked_field(
          t('in_person_proofing.form.state_id.same_address_as_id_no'),
          visible: false,
        )
      end

      it 'updates their previous selection from "Yes" TO "No, I live at a different address"' do
        complete_state_id_controller(user, same_address_as_id: true)
        # skip address step
        complete_ssn_step(user)
        # click update state ID button on the verify page
        click_link t('idv.buttons.change_state_id_label')
        # expect to be on the state ID page
        expect(page).to have_content(t('in_person_proofing.headings.update_state_id'))
        # change address
        fill_in t('in_person_proofing.form.state_id.address1'), with: ''
        fill_in t('in_person_proofing.form.state_id.address1'), with: 'test update address'
        # change response to No
        choose t('in_person_proofing.form.state_id.same_address_as_id_no')
        click_button t('forms.buttons.submit.update')
        # expect to be on address page
        expect(page).to have_content(t('in_person_proofing.headings.address'))
        # complete address step
        complete_address_step(user)
        # expect to be on verify page
        expect(page).to have_content(t('headings.verify'))
        expect(page).to have_current_path(idv_in_person_verify_info_path)
        # expect to see state ID address update on verify
        expect(page).to have_text('test update address').once # only state id address update
        # click update state id address
        click_link t('idv.buttons.change_state_id_label')
        # expect to be on the state ID page
        expect(page).to have_content(t('in_person_proofing.headings.update_state_id'))
        # check that the "No, I live at a different address" is checked"
        expect(page).to have_checked_field(
          t('in_person_proofing.form.state_id.same_address_as_id_no'),
          visible: false,
        )
      end

      it 'updates their previous selection from "No" TO "Yes,
        I live at the address on my state-issued ID"' do
        complete_state_id_controller(user, same_address_as_id: false)
        # expect to be on address page
        expect(page).to have_content(t('in_person_proofing.headings.address'))
        # complete address step
        complete_address_step(user)
        complete_ssn_step(user)
        # expect to be on verify page
        expect(page).to have_content(t('headings.verify'))
        expect(page).to have_current_path(idv_in_person_verify_info_path)
        # click update state ID button on the verify page
        click_link t('idv.buttons.change_state_id_label')
        # expect to be on the state ID page
        expect(page).to have_content(t('in_person_proofing.headings.update_state_id'))
        # change address
        fill_in t('in_person_proofing.form.state_id.address1'), with: ''
        fill_in t('in_person_proofing.form.state_id.address1'), with: 'test update address'
        # change response to Yes
        choose t('in_person_proofing.form.state_id.same_address_as_id_yes')
        click_button t('forms.buttons.submit.update')
        # expect to be back on verify page
        expect(page).to have_content(t('headings.verify'))
        expect(page).to have_current_path(idv_in_person_verify_info_path)
        # expect to see state ID address update on verify twice
        expect(page).to have_text('test update address').twice # for state id addr and addr update
        # click update state ID button on the verify page
        click_link t('idv.buttons.change_state_id_label')
        # expect to be on the state ID page
        expect(page).to have_content(t('in_person_proofing.headings.update_state_id'))
        expect(page).to have_checked_field(
          t('in_person_proofing.form.state_id.same_address_as_id_yes'),
          visible: false,
        )
      end
    end
  end

  context 'Validation' do
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
        '.usa-error-message',
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

      fill_in t('components.memorable_date.month'), with: '1'
      fill_in t('components.memorable_date.day'), with: '1'
      fill_in t('components.memorable_date.year'), with: Time.zone.now.strftime('%Y')
      click_idv_continue
      expect(page).to have_content(
        t(
          'in_person_proofing.form.state_id.memorable_date.errors.date_of_birth.range_min_age',
          app_name: APP_NAME,
        ),
      )

      year = (Time.zone.now - 13.years).strftime('%Y')
      fill_in t('components.memorable_date.year'), with: year
      click_idv_continue
      expect(page).not_to have_content(
        t(
          'in_person_proofing.form.state_id.memorable_date.errors.date_of_birth.range_min_age',
          app_name: APP_NAME,
        ),
      )
    end
  end

  context 'Transliterable Validation' do
    before(:each) do
      allow(IdentityConfig.store).to receive(:usps_ipp_transliteration_enabled).
        and_return(true)
    end

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

  context 'State selection' do
    it 'shows address hint when user selects state that has a specific hint',
       allow_browser_log: true do
      complete_steps_before_state_id_controller

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
      click_link t('idv.buttons.change_state_id_label')

      expect(page).to have_content(t('in_person_proofing.headings.update_state_id'))
      expect(page).to have_content(I18n.t('in_person_proofing.form.state_id.address1_hint'))
      expect(page).to have_content(I18n.t('in_person_proofing.form.state_id.address2_hint'))
    end

    it 'shows id number hint when user selects issuing state that has a specific hint',
       allow_browser_log: true do
      complete_steps_before_state_id_controller

      # expect default hint to be present
      expect(page).to have_content(t('in_person_proofing.form.state_id.state_id_number_hint'))

      select 'Texas',
             from: t('in_person_proofing.form.state_id.state_id_jurisdiction')
      expect(page).to have_content(t('in_person_proofing.form.state_id.state_id_number_texas_hint'))
      expect(page).not_to have_content(t('in_person_proofing.form.state_id.state_id_number_hint'))

      select 'Florida',
             from: t('in_person_proofing.form.state_id.state_id_jurisdiction')
      expect(page).not_to have_content(
        t('in_person_proofing.form.state_id.state_id_number_texas_hint'),
      )
      expect(page).not_to have_content(t('in_person_proofing.form.state_id.state_id_number_hint'))
      expect(page).to have_content strip_tags(
        t('in_person_proofing.form.state_id.state_id_number_florida_hint_html').gsub(
          /&nbsp;/, ' '
        ),
      )

      # select a state without a state specific hint
      select 'Ohio',
             from: t('in_person_proofing.form.state_id.state_id_jurisdiction')
      expect(page).to have_content(t('in_person_proofing.form.state_id.state_id_number_hint'))
      expect(page).not_to have_content(
        t('in_person_proofing.form.state_id.state_id_number_texas_hint'),
      )
      expect(page).not_to have_content(
        t('in_person_proofing.form.state_id.state_id_number_florida_hint_html'),
      )
    end
  end
end
