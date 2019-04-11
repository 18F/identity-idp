require 'rails_helper'

shared_examples 'front image step' do |simulate|
  feature 'doc auth front image step' do
    include IdvStepHelper
    include DocAuthHelper

    let(:user) { user_with_2fa }
    let(:max_attempts) { Figaro.env.acuant_max_attempts.to_i }
    before do
      allow(Figaro.env).to receive(:acuant_simulator).and_return(simulate)
      enable_doc_auth
      complete_doc_auth_steps_before_front_image_step(user)
      mock_assure_id_ok
    end

    it 'is on the correct page' do
      expect(page).to have_current_path(idv_doc_auth_front_image_step)
      expect(page).to have_content(t('doc_auth.headings.upload_front'))
    end

    it 'proceeds to the next page with valid info' do
      attach_image
      click_idv_continue

      expect(page).to have_current_path(idv_doc_auth_back_image_step)
    end

    it 'does not proceed to the next page with invalid info' do
      mock_assure_id_fail
      attach_image
      click_idv_continue

      expect(page).to have_current_path(idv_doc_auth_front_image_step)
    end

    it 'throttles calls to acuant and allows retry after the attempt window' do
      allow(Figaro.env).to receive(:acuant_max_attempts).and_return(max_attempts)
      max_attempts.times do
        attach_image
        click_idv_continue

        expect(page).to have_current_path(idv_doc_auth_back_image_step)
        click_on t('doc_auth.buttons.start_over')
        complete_doc_auth_steps_before_front_image_step(user)
      end

      attach_image
      click_idv_continue

      expect(page).to have_current_path(idv_doc_auth_front_image_step)

      Timecop.travel(Figaro.env.acuant_attempt_window_in_minutes.to_i.minutes.from_now) do
        complete_doc_auth_steps_before_front_image_step(user)
        attach_image
        click_idv_continue

        expect(page).to have_current_path(idv_doc_auth_back_image_step)
      end
    end
  end
end

feature 'doc auth front image' do
  it_behaves_like 'front image step', 'false'
  it_behaves_like 'front image step', 'true'
end
