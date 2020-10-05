require 'rails_helper'

feature 'doc auth ssn step' do
  include IdvStepHelper
  include DocAuthHelper
  include DocCaptureHelper

  context 'desktop' do
    before do
      sign_in_and_2fa_user
      complete_doc_auth_steps_before_ssn_step
    end

    it 'is on the correct page' do
      expect(page).to have_current_path(idv_doc_auth_ssn_step)
      expect(page).to have_content(t('doc_auth.headings.ssn'))
      expect(page).to have_content(t('doc_auth.headings.capture_complete'))
    end

    it 'proceeds to the next page with valid info' do
      fill_out_ssn_form_ok
      click_idv_continue

      expect(page).to have_current_path(idv_doc_auth_verify_step)
    end

    it 'does not proceed to the next page with invalid info' do
      fill_out_ssn_form_fail
      click_idv_continue

      expect(page).to have_current_path(idv_doc_auth_ssn_step)
    end
  end

  context 'doc capture hand-off' do
    let(:document_capture_step_enabled) { true }

    before do
      allow(FeatureManagement).to receive(:document_capture_step_enabled?).
        and_return(document_capture_step_enabled)
      allow(LoginGov::Hostdata::EC2).to receive(:load).
        and_return(OpenStruct.new(region: 'us-west-2', account_id: '123456789'))
      in_doc_capture_session { complete_doc_capture_steps_before_capture_complete_step }
      click_on t('forms.buttons.continue')
    end

    context 'document capture step enabled' do
      let(:document_capture_step_enabled) { true }

      it 'is on the correct page' do
        expect(page).to have_current_path(idv_doc_auth_ssn_step)
        expect(page).to have_content(t('doc_auth.headings.ssn'))
        expect(page).to have_content(t('doc_auth.headings.capture_complete'))
      end

      it 'proceeds to the next page with valid info' do
        fill_out_ssn_form_ok
        click_idv_continue

        expect(page).to have_current_path(idv_doc_auth_verify_step)
      end

      it 'does not proceed to the next page with invalid info' do
        fill_out_ssn_form_fail
        click_idv_continue

        expect(page).to have_current_path(idv_doc_auth_ssn_step)
      end
    end

    context 'document capture step disabled' do
      let(:document_capture_step_enabled) { false }

      it 'is on the correct page' do
        expect(page).to have_current_path(idv_doc_auth_ssn_step)
        expect(page).to have_content(t('doc_auth.headings.ssn'))
      end

      it 'proceeds to the next page with valid info' do
        fill_out_ssn_form_ok
        click_idv_continue

        expect(page).to have_current_path(idv_doc_auth_verify_step)
      end

      it 'does not proceed to the next page with invalid info' do
        fill_out_ssn_form_fail
        click_idv_continue

        expect(page).to have_current_path(idv_doc_auth_ssn_step)
      end
    end
  end
end
