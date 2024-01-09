require 'rails_helper'

RSpec.describe 'doc auth In person proofing residential address step', js: true do
  include IdvStepHelper
  include InPersonHelper

  before do
    allow(IdentityConfig.store).to receive(:in_person_proofing_enabled).and_return(true)
    allow(IdentityConfig.store).to receive(:in_person_residential_address_controller_enabled).
      and_return(true)
  end

  context 'when visiting address for the first time' do
    it 'displays correct heading and button text', allow_browser_log: true do
      complete_idv_steps_before_address
      # residential address page
      expect(page).to have_current_path(idv_in_person_proofing_address_url)

      expect(page).to have_content(t('forms.buttons.continue'))
      expect(page).to have_content(t('in_person_proofing.headings.address'))
    end

    it 'allows the user to cancel and start over', allow_browser_log: true do
      complete_idv_steps_before_address

      expect(page).not_to have_content('forms.buttons.back')

      click_link t('links.cancel')
      click_on t('idv.cancel.actions.start_over')
      expect(page).to have_current_path(idv_welcome_path)
    end

    it 'allows the user to cancel and return', allow_browser_log: true do
      complete_idv_steps_before_address

      expect(page).not_to have_content('forms.buttons.back')

      click_link t('links.cancel')
      click_on t('idv.cancel.actions.keep_going')
      expect(page).to have_current_path(idv_in_person_proofing_address_url)
    end

    it 'allows user to submit valid inputs on form', allow_browser_log: true do
      user = user_with_2fa
      complete_idv_steps_before_address(user)
      fill_out_address_form_ok
      click_idv_continue

      expect(page).to have_current_path(idv_in_person_ssn_url, wait: 10)
      complete_ssn_step(user)

      expect_in_person_step_indicator_current_step(t('step_indicator.flows.idv.verify_info'))
      expect(page).to have_current_path(idv_in_person_verify_info_url)
      expect(page).to have_text(InPersonHelper::GOOD_ADDRESS1)
      expect(page).to have_text(InPersonHelper::GOOD_ADDRESS2)
      expect(page).to have_text(InPersonHelper::GOOD_CITY)
      expect(page).to have_text(InPersonHelper::GOOD_ZIPCODE)
      expect(page).to have_text(Idp::Constants::MOCK_IDV_APPLICANT_STATE)
    end
  end

  context 'transliteration' do
    before(:each) do
      allow(IdentityConfig.store).to receive(:usps_ipp_transliteration_enabled).
        and_return(true)
    end

    it 'shows validation errors',
       allow_browser_log: true do
      complete_idv_steps_before_address

      fill_out_address_form_ok(same_address_as_id: false)
      fill_in t('idv.form.address1'), with: '#1 $treet'
      fill_in t('idv.form.address2'), with: 'Gr@nd Lañe^'
      fill_in t('idv.form.city'), with: 'N3w C!ty'
      click_idv_continue

      expect(page).to have_content(
        I18n.t(
          'in_person_proofing.form.address.errors.unsupported_chars',
          char_list: '$',
        ),
      )

      expect(page).to have_content(
        I18n.t(
          'in_person_proofing.form.address.errors.unsupported_chars',
          char_list: '@, ^',
        ),
      )

      expect(page).to have_content(
        I18n.t(
          'in_person_proofing.form.address.errors.unsupported_chars',
          char_list: '!, 3',
        ),
      )

      select InPersonHelper::GOOD_STATE, from: t('idv.form.state')
      fill_in t('idv.form.address1'),
              with: InPersonHelper::GOOD_ADDRESS1
      fill_in t('idv.form.address2'),
              with: InPersonHelper::GOOD_ADDRESS2
      fill_in t('idv.form.city'),
              with: InPersonHelper::GOOD_CITY
      fill_in t('idv.form.zipcode'),
              with: InPersonHelper::GOOD_ZIPCODE
      click_idv_continue

      expect(page).to have_current_path(idv_in_person_ssn_url, wait: 10)
    end
  end

  context 'State selection' do
    it 'shows address hint when user selects state that has a specific hint',
       allow_browser_log: true do
      complete_idv_steps_before_address

      # address form
      select 'Puerto Rico',
             from: t('idv.form.state')
      expect(page).to have_content(I18n.t('in_person_proofing.form.state_id.address1_hint'))
      expect(page).to have_content(I18n.t('in_person_proofing.form.state_id.address2_hint'))

      # change selection
      fill_out_address_form_ok(same_address_as_id: false)
      expect(page).not_to have_content(I18n.t('in_person_proofing.form.state_id.address1_hint'))
      expect(page).not_to have_content(I18n.t('in_person_proofing.form.state_id.address2_hint'))

      # re-select puerto rico
      select 'Puerto Rico',
             from: t('idv.form.state')
      click_idv_continue

      # ssn page
      expect(page).to have_current_path(idv_in_person_ssn_url)
      complete_ssn_step

      # verify page
      expect(page).to have_current_path(idv_in_person_verify_info_path, wait: 10)
      expect(page).to have_text('PR')

      # update address
      click_link t('idv.buttons.change_address_label')

      expect(page).to have_content(t('in_person_proofing.headings.update_address'))
      expect(page).to have_content(I18n.t('in_person_proofing.form.state_id.address1_hint'))
      expect(page).to have_content(I18n.t('in_person_proofing.form.state_id.address2_hint'))
    end
  end
end
