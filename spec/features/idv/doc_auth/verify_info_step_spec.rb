require 'rails_helper'

feature 'doc auth verify_info step', :js do
  include IdvStepHelper
  include DocAuthHelper

  let(:fake_analytics) { FakeAnalytics.new }
  let(:fake_attempts_tracker) { IrsAttemptsApiTrackingHelper::FakeAttemptsTracker.new }

  context 'with verify_info_controller enabled' do
    before do
      allow(IdentityConfig.store).to receive(:doc_auth_verify_info_controller_enabled).
        and_return(true)
      allow_any_instance_of(ApplicationController).to receive(:analytics).and_return(fake_analytics)
      allow_any_instance_of(ApplicationController).to receive(:irs_attempts_api_tracker).
        and_return(fake_attempts_tracker)
      sign_in_and_2fa_user
      complete_doc_auth_steps_before_verify_step
    end

    it 'sends the user to start doc auth if there is no pii from the document in session' do
      visit sign_out_url
      sign_in_and_2fa_user
      visit idv_doc_auth_verify_step

      expect(page).to have_current_path(idv_doc_auth_welcome_step)
    end

    it 'displays the expected content' do
      expect(page).to have_current_path(idv_verify_info_path)
      expect(page).to have_content(t('headings.verify'))
      expect(page).to have_content(t('step_indicator.flows.idv.verify_info'))

      # SSN is masked until revealed
      expect(page).to have_text('9**-**-***4')
      expect(page).not_to have_text(DocAuthHelper::GOOD_SSN)
      check t('forms.ssn.show')
      expect(page).not_to have_text('9**-**-***4')
      expect(page).to have_text(DocAuthHelper::GOOD_SSN)
    end

    it 'allows the user to enter in a new address and displays updated info' do
      click_button t('idv.buttons.change_address_label')
      fill_in 'idv_form_zipcode', with: '12345'
      click_button t('forms.buttons.submit.update')

      expect(page).to have_current_path(idv_verify_info_path)

      expect(page).to have_content('12345')
    end

    it 'allows the user to enter in a new ssn and displays updated info' do
      click_button t('idv.buttons.change_ssn_label')
      fill_in t('idv.form.ssn_label_html'), with: '900456789'
      click_button t('forms.buttons.submit.update')

      expect(page).to have_current_path(idv_verify_info_path)

      expect(page).to have_text('9**-**-***9')
      check t('forms.ssn.show')
      expect(page).to have_text('900-45-6789')
    end

    it 'proceeds to the next page upon confirmation' do
      expect(fake_attempts_tracker).to receive(:idv_verification_submitted).with(
        success: true,
        failure_reason: nil,
        document_state: 'MT',
        document_number: '1111111111111',
        document_issued: '2019-12-31',
        document_expiration: '2099-12-31',
        first_name: 'FAKEY',
        last_name: 'MCFAKERSON',
        date_of_birth: '1938-10-06',
        address: '1 FAKE RD',
        ssn: '900-66-1234',
      )
      sign_in_and_2fa_user
      complete_doc_auth_steps_before_verify_step
      click_idv_continue

      expect(page).to have_current_path(idv_phone_path)
      expect(page).to have_content(t('doc_auth.forms.doc_success'))
      user = User.last
      expect(user.proofing_component.resolution_check).to eq(Idp::Constants::Vendors::LEXIS_NEXIS)
      expect(user.proofing_component.source_check).to eq(Idp::Constants::Vendors::AAMVA)
      expect(DocAuthLog.find_by(user_id: user.id).aamva).to eq(true)
      expect(fake_analytics).to have_logged_event(
        'IdV: doc auth verify proofing results',
        hash_including(address_edited: false),
      )
    end
  end
end
