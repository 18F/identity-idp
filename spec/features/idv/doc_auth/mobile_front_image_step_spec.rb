require 'rails_helper'

shared_examples 'mobile front image step' do |simulate|
  feature 'doc auth mobile front image step' do
    include IdvStepHelper
    include DocAuthHelper

    before do
      allow(Figaro.env).to receive(:acuant_simulator).and_return(simulate)
      enable_doc_auth
      complete_doc_auth_steps_before_mobile_front_image_step
      mock_assure_id_ok
    end

    it 'is on the correct page' do
      expect(page).to have_current_path(idv_doc_auth_mobile_front_image_step)
      expect(page).to have_content(t('doc_auth.headings.take_pic_front'))
    end

    it 'proceeds to the next page with valid info' do
      attach_image
      click_idv_continue

      expect(page).to have_current_path(idv_doc_auth_mobile_back_image_step)
    end

    it 'does not proceed to the next page with invalid info' do
      mock_assure_id_fail
      attach_image
      click_idv_continue

      expect(page).to have_current_path(idv_doc_auth_mobile_front_image_step)
    end
  end
end

feature 'doc auth front image' do
  it_behaves_like 'mobile front image step', 'false'
  it_behaves_like 'mobile front image step', 'true'
end
