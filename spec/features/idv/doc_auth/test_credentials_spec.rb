require 'rails_helper'

shared_examples 'test credentials' do |simulate|
  feature 'doc auth test credentials' do
    include IdvStepHelper
    include DocAuthHelper

    before do
      setup_acuant_simulator(enabled: simulate)
      enable_doc_auth
    end

    it 'proceeds to the next page after front_image with valid test credentials' do
      complete_doc_auth_steps_before_front_image_step
      enable_test_credentials

      upload_test_credentials_and_continue

      expect(page).to have_current_path(idv_doc_auth_back_image_step)
    end

    it 'does not proceed to next page from front_image if test credentials are disabled' do
      complete_doc_auth_steps_before_front_image_step

      upload_test_credentials_and_continue

      expect(page).to have_current_path(idv_doc_auth_front_image_step)
    end

    it 'proceeds to ssn then verify pii page after back_image with valid test credentials' do
      complete_doc_auth_steps_before_back_image_step
      enable_test_credentials

      upload_test_credentials_and_continue

      expect(page).to have_current_path(idv_doc_auth_ssn_step)

      fill_out_ssn_form_ok
      click_idv_continue
      expect(page).to have_content('Jane')
    end

    it 'does not proceed to next page from back_image if test credentials are disabled' do
      complete_doc_auth_steps_before_back_image_step

      upload_test_credentials_and_continue

      expect(page).to have_current_path(idv_doc_auth_back_image_step)
    end

    it 'triggers an acuant error' do
      complete_doc_auth_steps_before_back_image_step
      enable_test_credentials

      attach_file 'doc_auth_image', 'spec/fixtures/ial2_test_credential_forces_error.yml'
      click_idv_continue

      expect(page).to have_current_path(idv_doc_auth_back_image_step)
      expect(page).to have_content(I18n.t('friendly_errors.doc_auth.barcode_could_not_be_read'))
    end
  end

  def upload_test_credentials_and_continue
    re_mock_assure_id

    attach_file 'doc_auth_image', 'spec/fixtures/ial2_test_credential.yml'
    click_idv_continue
  end

  def re_mock_assure_id
    allow_any_instance_of(Idv::Acuant::AssureId).to receive(:create_document).
      and_return([true, '123'])
    allow_any_instance_of(Idv::Acuant::AssureId).to receive(:post_front_image).
      and_return([false, ''])
    allow_any_instance_of(Idv::Acuant::AssureId).to receive(:post_back_image).
      and_return([false, ''])
  end
end

feature 'doc auth test credentials' do
  it_behaves_like 'test credentials', false
end
