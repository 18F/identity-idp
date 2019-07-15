require 'rails_helper'

shared_examples 'front image step' do |simulate|
  feature 'doc auth front image step' do
    include IdvStepHelper
    include DocAuthHelper
    include InPersonHelper

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

    it 'displays tips and sample images' do
      expect(page).to have_current_path(idv_doc_auth_front_image_step)
      expect(page).to have_content(I18n.t('doc_auth.tips.text1'))
      expect(page).to have_css('img[src*=state-id-sample-front]')
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

    it 'offers in person option on failure' do
      enable_in_person_proofing

      expect(page).to_not have_link(t('in_person_proofing.opt_in_link'),
                                    href: idv_in_person_welcome_step)

      mock_assure_id_fail
      attach_image
      click_idv_continue

      expect(page).to have_link(t('in_person_proofing.opt_in_link'),
                                href: idv_in_person_welcome_step)
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

    it 'catches network connection errors on post_front_image' do
      allow_any_instance_of(Idv::Acuant::AssureId).to receive(:post_front_image).
        and_raise(Faraday::ConnectionFailed.new('error'))

      attach_image
      click_idv_continue

      unless simulate
        expect(page).to have_current_path(idv_doc_auth_front_image_step)
        expect(page).to have_content(I18n.t('errors.doc_auth.acuant_network_error'))
      end
    end

    it 'catches network connection errors on results' do
      allow_any_instance_of(Idv::Acuant::AssureId).to receive(:results).
        and_raise(Faraday::ConnectionFailed.new('error'))

      attach_image
      click_idv_continue

      unless simulate
        expect(page).to have_current_path(idv_doc_auth_front_image_step)
        expect(page).to have_content(I18n.t('errors.doc_auth.acuant_network_error'))
      end
    end

    it 'catches network timeout errors on post_front_image' do
      allow_any_instance_of(Idv::Acuant::AssureId).to receive(:post_front_image).
        and_raise(Faraday::TimeoutError)

      attach_image
      click_idv_continue

      unless simulate
        expect(page).to have_current_path(idv_doc_auth_front_image_step)
        expect(page).to have_content(I18n.t('errors.doc_auth.acuant_network_error'))
      end
    end

    it 'catches network timeout errors on results' do
      allow_any_instance_of(Idv::Acuant::AssureId).to receive(:results).
        and_raise(Faraday::TimeoutError)

      attach_image
      click_idv_continue

      unless simulate
        expect(page).to have_current_path(idv_doc_auth_front_image_step)
        expect(page).to have_content(I18n.t('errors.doc_auth.acuant_network_error'))
      end
    end
  end
end

feature 'doc auth front image' do
  it_behaves_like 'front image step', 'false'
  it_behaves_like 'front image step', 'true'
end
