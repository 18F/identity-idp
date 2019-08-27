require 'rails_helper'

shared_examples 'back image step' do |simulate|
  feature 'doc auth back image step' do
    include IdvStepHelper
    include DocAuthHelper

    let(:user) { user_with_2fa }
    let(:max_attempts) { Figaro.env.acuant_max_attempts.to_i }
    before do
      allow(Figaro.env).to receive(:acuant_simulator).and_return(simulate)
      enable_doc_auth
      complete_doc_auth_steps_before_back_image_step(user)
      mock_assure_id_ok
    end

    it 'is on the correct page' do
      expect(page).to have_current_path(idv_doc_auth_back_image_step)
      expect(page).to have_content(t('doc_auth.headings.upload_back'))
    end

    it 'displays tips and sample images' do
      expect(page).to have_current_path(idv_doc_auth_back_image_step)
      expect(page).to have_content(I18n.t('doc_auth.tips.text1'))
      expect(page).to have_css('img[src*=state-id-sample-back]')
    end

    it 'proceeds to the next page with valid info' do
      attach_image
      click_idv_continue

      expect(page).to have_current_path(idv_doc_auth_ssn_step)
    end

    it 'proceeds to the next page if the user does not have a phone' do
      complete_doc_auth_steps_before_back_image_step(
        create(:user, :with_authentication_app, :with_piv_or_cac),
      )
      attach_image
      click_idv_continue

      expect(page).to have_current_path(idv_doc_auth_ssn_step)
    end

    it 'does not proceed to the next page with invalid info' do
      allow_any_instance_of(Idv::Acuant::AssureId).to receive(:post_back_image).
        and_return([false, ''])
      attach_image
      click_idv_continue

      expect(page).to have_current_path(idv_doc_auth_back_image_step) unless simulate
    end

    it 'does not proceed to the next page with result=2' do
      allow_any_instance_of(Idv::Acuant::AssureId).to receive(:results).
        and_return([true, assure_id_results_with_result_2])
      attach_image
      click_idv_continue

      expect(page).to have_current_path(idv_doc_auth_front_image_step) unless simulate
      expect(page).to have_content(I18n.t('errors.doc_auth.general_error')) unless simulate
      expect(page).to have_content(I18n.t('errors.doc_auth.general_info')) unless simulate
    end

    it 'throttles calls to acuant and allows attempts after the attempt window' do
      (max_attempts / 2).times do
        attach_image
        click_idv_continue

        expect(page).to have_current_path(idv_doc_auth_ssn_step)
        click_on t('doc_auth.buttons.start_over')
        complete_doc_auth_steps_before_back_image_step(user)
      end

      attach_image
      click_idv_continue

      expect(page).to have_current_path(idv_doc_auth_front_image_step)

      Timecop.travel((Figaro.env.acuant_attempt_window_in_minutes.to_i + 1).minutes.from_now) do
        complete_doc_auth_steps_before_back_image_step(user)
        attach_image
        click_idv_continue
        expect(page).to have_current_path(idv_doc_auth_ssn_step)
      end
    end

    it 'catches network connection errors' do
      allow_any_instance_of(Idv::Acuant::AssureId).to receive(:post_back_image).
        and_raise(Faraday::ConnectionFailed.new('error'))

      attach_image
      click_idv_continue

      unless simulate
        expect(page).to have_current_path(idv_doc_auth_back_image_step)
        expect(page).to have_content(I18n.t('errors.doc_auth.acuant_network_error'))
      end
    end

    it 'catches network timeout errors' do
      allow_any_instance_of(Idv::Acuant::AssureId).to receive(:post_back_image).
        and_raise(Faraday::TimeoutError)

      attach_image
      click_idv_continue

      unless simulate
        expect(page).to have_current_path(idv_doc_auth_back_image_step)
        expect(page).to have_content(I18n.t('errors.doc_auth.acuant_network_error'))
      end
    end
  end
end

feature 'doc auth back image' do
  it_behaves_like 'back image step', 'false'
  it_behaves_like 'back image step', 'true'
end
