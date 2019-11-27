require 'rails_helper'

shared_examples 'back image step' do |simulate|
  feature 'doc auth back image step' do
    include IdvStepHelper
    include DocAuthHelper

    let(:user) { user_with_2fa }
    let(:max_attempts) { Figaro.env.acuant_max_attempts.to_i }
    before do
      setup_acuant_simulator(enabled: simulate)
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
      expect(user.proofing_component.document_check).to eq('acuant')
      expect(user.proofing_component.document_type).to eq('state_id')
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

      unless simulate
        expect(page).to have_current_path(idv_doc_auth_front_image_step)
        expect(page).to have_content(I18n.t('errors.doc_auth.general_error'))
        expect(page).to have_content(strip_tags(I18n.t('errors.doc_auth.general_info'))[0..32])
      end
    end

    context 'when a known error occures with a friendly translation' do
      known_errors = {'the_document_type_could_not_be_determined':
                        'The document type could not be determined',
                      'the_2d_barcode_could_not_be_read': 'The 2D barcode could not be read',
                      'a_visible_pattern_was_not_found': 'A visible pattern was not found',
                      'evidence_suggests_the_image_has_been_tampered_with_or_digitally_manipulated':
                        'Evidence suggests the image has been tampered with or digitally manipulated.',
                      'the_photo_printing_technique_was_not_detected':
                        'The photo printing technique was not detected',
                      'the_document_has_expired': 'The document has expired',
                      'the_birth_date_is_not_valid': 'The birth date is not valid',
                      'the_expiration_date_is_not_valid': 'The expiration date is not valid',
                      'the_substrate_printing_technique_was_not_detected':
                        'The substrate printing technique was not detected',
                      'the_color_response_is_incorrect': 'The color response is incorrect',
                      'the_issue_date_is_not_valid': 'The issue date is not valid',
                      'the_full_names_do_not_match': 'The full names do not match',
                      'the_document_number_check_digit_is_incorrect':
                        'The document number check digit is incorrect',
                      'the_photo_lacks_the_expected_appearance': 'The photo lacks the expected appearance',
                      'the_birth_dates_do_not_match': 'The birth dates do not match',
                      'the_control_numbers_do_not_match': 'The control numbers do not match',
                      'the_composite_check_digit_is_incorrect': 'The composite check digit is incorrect',
                      'the_sexes_do_not_match': 'The sexes do not match',
                      'the_2d_barcode_is_formatted_incorrectly': 'The 2D barcode is formatted incorrectly',
                      'document_image_load_failure': 'Document image load failure',
                      'document_not_found': 'Document Not Found',
                      'color_pixel_depth_must_be_24-bit': 'Color pixel depth must be 24-bit',
                      'duplicate_document_side': 'Duplicate Document Side',
                      'document_complete_or_in_error_state': 'Document complete or in error state',
                      'internal_server_error': 'Internal Server Error'}
      known_errors.each do |key, error|
        it "returns errors.doc_auth.#{key} I18n value when error is '#{error}'" do
          allow_any_instance_of(Idv::Acuant::AssureId).to receive(:results).
            and_return([true, assure_id_results_with_result_2(error)])
          attach_image
          click_idv_continue

          unless simulate
            expect(page).to have_current_path(idv_doc_auth_front_image_step)
            expect(page).to have_content(I18n.t("errors.doc_auth.#{key}"))
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
  end
end

feature 'doc auth back image' do
  it_behaves_like 'back image step', false
  it_behaves_like 'back image step', true
end
