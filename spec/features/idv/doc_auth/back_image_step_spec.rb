require 'rails_helper'

shared_examples 'back image step' do |simulate|
  feature 'doc auth back image step' do
    include IdvStepHelper
    include DocAuthHelper

    let(:max_attempts) { Figaro.env.acuant_max_attempts.to_i }
    let(:user) { user_with_2fa }

    before do
      setup_acuant_simulator(enabled: simulate)
      sign_in_and_2fa_user(user)
      complete_doc_auth_steps_before_back_image_step
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
      user = User.first
      expect(user.proofing_component.document_check).to eq('acuant')
      expect(user.proofing_component.document_type).to eq('state_id')
    end

    it 'allows the use of a base64 encoded canvas url representation of the image' do
      unless simulate
        assure_id = Idv::Acuant::AssureId.new
        expect(Idv::Acuant::AssureId).to receive(:new).and_return(assure_id)
        expect(assure_id).to receive(:post_back_image).
          with(doc_auth_image_canvas_data).
          and_return([true, ''])
      end

      attach_image_canvas_url
      click_idv_continue

      expect(page).to have_current_path(idv_doc_auth_ssn_step)
    end

    it 'proceeds to the next page if the user does not have a phone' do
      user = create(:user, :with_authentication_app, :with_piv_or_cac)
      sign_in_and_2fa_user(user)
      complete_doc_auth_steps_before_back_image_step
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

      unless simulate
        expect(page).to have_current_path(idv_doc_auth_front_image_step)
        expect(page).to have_content(I18n.t('errors.doc_auth.general_error'))
        expect(page).to have_content(strip_tags(I18n.t('errors.doc_auth.general_info'))[0..32])
      end
    end

    context 'when an error occurs with a friendly message' do
      FRIENDLY_ERROR_CONFIG['doc_auth'].each do |key, error|
        it "returns friendly_errors.doc_auth.#{key} I18n value" do
          allow_any_instance_of(Idv::Acuant::AssureId).to receive(:results).
            and_return([true, assure_id_results_with_result_2(error)])
          attach_image
          click_idv_continue

          unless simulate
            expect(page).to have_current_path(idv_doc_auth_front_image_step)
            expect(page).to have_content(I18n.t("friendly_errors.doc_auth.#{key}"))
          end
        end
      end
    end

    it 'throttles calls to acuant and allows attempts after the attempt window' do
      (max_attempts / 2).times do
        attach_image
        click_idv_continue

        expect(page).to have_current_path(idv_doc_auth_ssn_step)

        click_on t('doc_auth.buttons.start_over')
        complete_doc_auth_steps_before_back_image_step
      end

      expect(page).to have_current_path(idv_session_errors_throttled_path)

      Timecop.travel((Figaro.env.acuant_attempt_window_in_minutes.to_i + 1).minutes.from_now) do
        sign_in_and_2fa_user(user)
        complete_doc_auth_steps_before_back_image_step
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

    it 'catches network timeout errors posting back image' do
      allow_any_instance_of(Idv::Acuant::AssureId).to receive(:post_back_image).
        and_raise(Faraday::TimeoutError)

      attach_image
      click_idv_continue

      unless simulate
        expect(page).to have_current_path(idv_doc_auth_back_image_step)
        expect(page).to have_content(I18n.t('errors.doc_auth.acuant_network_error'))
      end
    end

    it 'catches network timeout errors verifying results' do
      allow_any_instance_of(Idv::Acuant::AssureId).to receive(:results).
        and_raise(Faraday::TimeoutError)

      attach_image
      click_idv_continue
      unless simulate
        expect(page).to have_current_path(idv_doc_auth_back_image_step)
        expect(page).to have_content(I18n.t('errors.doc_auth.acuant_network_error'))
      end
    end

    it 'catches acuant timeout errors verifying results' do
      allow_any_instance_of(Idv::Acuant::AssureId).to receive(:results).
        and_raise(Timeout::Error)

      attach_image
      click_idv_continue
      unless simulate
        expect(page).to have_current_path(idv_doc_auth_back_image_step)
        expect(page).to have_content(I18n.t('errors.doc_auth.acuant_network_error'))
      end
    end

    it 'notifies newrelic when acuant goes over the rack timeout' do
      allow_any_instance_of(Idv::Acuant::AssureId).to receive(:results).
        and_raise(Rack::Timeout::RequestTimeoutException.new(nil))

      attach_image

      expect(NewRelic::Agent).to receive(:notice_error) unless simulate
      click_idv_continue
    end
  end
end

feature 'doc auth back image' do
  it_behaves_like 'back image step', false
  it_behaves_like 'back image step', true
end
