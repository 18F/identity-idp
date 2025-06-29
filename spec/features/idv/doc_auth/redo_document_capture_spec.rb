require 'rails_helper'

RSpec.feature 'document capture step', :js do
  include IdvStepHelper
  include DocAuthHelper
  include DocCaptureHelper
  include AbTestsHelper
  include ActionView::Helpers::DateHelper

  let(:max_attempts) { IdentityConfig.store.doc_auth_max_attempts }
  let(:fake_analytics) { FakeAnalytics.new }
  let(:attempts_api_tracker) { AttemptsApiTrackingHelper::FakeAttemptsTracker.new }

  before(:each) do
    allow_any_instance_of(ApplicationController).to receive(:analytics).and_return(fake_analytics)
    allow_any_instance_of(ApplicationController).to receive(:attempts_api_tracker).and_return(
      attempts_api_tracker,
    )
    allow_any_instance_of(ServiceProviderSession).to receive(:sp_name).and_return(@sp_name)
  end

  before(:all) do
    @sp_name = 'Test SP'
    @user = user_with_2fa
  end

  after(:all) { @user.destroy }

  context 'standard desktop flow' do
    before do
      visit_idp_from_oidc_sp_with_ial2
      sign_in_and_2fa_user(@user)
      complete_doc_auth_steps_before_document_capture_step
    end

    context 'rate limits calls to backend docauth vendor', allow_browser_log: true do
      before do
        allow(IdentityConfig.store).to receive(:doc_auth_max_attempts).and_return(max_attempts)
        DocAuth::Mock::DocAuthMockClient.mock_response!(
          method: :post_front_image,
          response: DocAuth::Response.new(
            success: false,
            errors: { network: I18n.t('doc_auth.errors.general.network_error') },
          ),
        )

        (max_attempts - 1).times do
          attach_and_submit_images
          click_on t('idv.failure.button.warning')
        end
      end

      it 'redirects to the rate limited error page' do
        freeze_time do
          attach_and_submit_images
          timeout = distance_of_time_in_words(
            RateLimiter.attempt_window_in_minutes(:idv_doc_auth).minutes,
          )
          message = strip_tags(t('doc_auth.errors.rate_limited_text_html', timeout: timeout))
          expect(page).to have_content(message)
          expect(page).to have_current_path(idv_session_errors_rate_limited_path)
        end
      end

      it 'logs the rate limited analytics event for doc_auth' do
        expect(attempts_api_tracker).to receive(:idv_rate_limited).with(
          limiter_type: :idv_doc_auth,
        )

        attach_and_submit_images
        expect(fake_analytics).to have_logged_event(
          'Rate Limit Reached',
          limiter_type: :idv_doc_auth,
        )
      end

      context 'successfully processes image on last attempt' do
        before { DocAuth::Mock::DocAuthMockClient.reset! }

        it 'proceeds to the next page with valid info' do
          expect(page).to have_current_path(idv_document_capture_url)
          expect(page).not_to have_content(t('doc_auth.headings.document_capture_selfie'))
          attach_and_submit_images
          expect(page).to have_current_path(idv_ssn_url)

          visit idv_document_capture_path

          expect(page).to have_current_path(idv_session_errors_rate_limited_path)
        end
      end
    end

    it 'catches network connection errors on post_front_image', allow_browser_log: true do
      DocAuth::Mock::DocAuthMockClient.mock_response!(
        method: :post_front_image,
        response: DocAuth::Response.new(
          success: false,
          errors: { network: I18n.t('doc_auth.errors.general.network_error') },
        ),
      )

      attach_and_submit_images

      expect(page).to have_current_path(idv_document_capture_url)
      expect(page).to have_content(I18n.t('doc_auth.errors.general.network_error'))
    end

    it 'does not track state if state tracking is disabled' do
      allow(IdentityConfig.store).to receive(:state_tracking_enabled).and_return(false)
      attach_and_submit_images

      expect(DocAuthLog.find_by(user_id: @user.id).state).to be_nil
    end
  end

  context 'standard mobile flow' do
    it 'proceeds to the next page with valid info' do
      perform_in_browser(:mobile) do
        visit_idp_from_oidc_sp_with_ial2
        sign_in_and_2fa_user(@user)
        complete_doc_auth_steps_before_document_capture_step

        expect(page).to have_current_path(idv_document_capture_url)
        expect_step_indicator_current_step(t('step_indicator.flows.idv.verify_id'))
        expect(page).not_to have_content(t('doc_auth.headings.document_capture_selfie'))

        # doc auth is successful while liveness is not req'd
        use_id_image('ial2_test_credential_no_liveness.yml')
        submit_images

        expect(page).to have_current_path(idv_ssn_url)
        expect_costing_for_document
        expect(DocAuthLog.find_by(user_id: @user.id).state).to eq('NY')

        fill_out_ssn_form_ok
        click_idv_continue
        complete_verify_step
        expect(page).to have_current_path(idv_phone_url)
      end
    end
  end

  context 'facial match is required', allow_browser_log: true do
    before do
      allow(IdentityConfig.store).to receive(:use_vot_in_sp_requests).and_return(true)
      visit_idp_from_oidc_sp_with_ial2(facial_match_required: true)
      sign_in_and_2fa_user(@user)
      complete_doc_auth_steps_before_document_capture_step
    end

    it 'user can go through verification uploading ID and selfie on seprerate pages' do
      expect(page).to have_current_path(idv_document_capture_url)
      expect(page).not_to have_content(t('doc_auth.tips.document_capture_selfie_text1'))
      attach_images
      click_continue
      expect(page).to have_title(t('doc_auth.headings.selfie_capture'))
      expect(page).to have_content(t('doc_auth.tips.document_capture_selfie_text1'))
      click_button 'Take photo'
      attach_selfie
      submit_images
      expect(page).to have_content(t('doc_auth.headings.capture_complete'))
    end

    it 'initial verification failure allows user to resubmit all images in 1 page' do
      attach_images(
        Rails.root.join(
          'spec', 'fixtures',
          'ial2_test_credential_multiple_doc_auth_failures_both_sides.yml'
        ),
      )
      click_continue
      click_button 'Take photo'
      attach_selfie(
        Rails.root.join(
          'spec', 'fixtures',
          'ial2_test_credential_forces_error.yml'
        ),
      )
      submit_images
      expect(page).to have_content(t('doc_auth.errors.rate_limited_heading'))
      click_try_again
      expect(page).to have_content(t('doc_auth.headings.review_issues'))
      attach_images
      submit_images
      expect(page).to have_content(t('doc_auth.headings.capture_complete'))
    end
  end

  context 'standard desktop flow' do
    before do
      visit_idp_from_oidc_sp_with_ial2
      sign_in_and_2fa_user(@user)
      complete_doc_auth_steps_before_document_capture_step
    end

    context 'rate limits calls to backend docauth vendor', allow_browser_log: true do
      before do
        allow(IdentityConfig.store).to receive(:doc_auth_max_attempts).and_return(max_attempts)
        DocAuth::Mock::DocAuthMockClient.mock_response!(
          method: :post_front_image,
          response: DocAuth::Response.new(
            success: false,
            errors: { network: I18n.t('doc_auth.errors.general.network_error') },
          ),
        )

        (max_attempts - 1).times do
          attach_and_submit_images
          click_on t('idv.failure.button.warning')
        end
      end

      it 'redirects to the rate limited error page' do
        freeze_time do
          attach_and_submit_images
          timeout = distance_of_time_in_words(
            RateLimiter.attempt_window_in_minutes(:idv_doc_auth).minutes,
          )
          message = strip_tags(t('doc_auth.errors.rate_limited_text_html', timeout: timeout))
          expect(page).to have_content(message)
          expect(page).to have_current_path(idv_session_errors_rate_limited_path)
        end
      end

      it 'logs the rate limited analytics event for doc_auth' do
        expect(attempts_api_tracker).to receive(:idv_rate_limited).with(
          limiter_type: :idv_doc_auth,
        )

        attach_and_submit_images
        expect(fake_analytics).to have_logged_event(
          'Rate Limit Reached',
          limiter_type: :idv_doc_auth,
        )
      end

      context 'successfully processes image on last attempt' do
        before { DocAuth::Mock::DocAuthMockClient.reset! }

        it 'proceeds to the next page with valid info' do
          expect(page).to have_current_path(idv_document_capture_url)
          expect(page).not_to have_content(t('doc_auth.headings.document_capture_selfie'))
          attach_and_submit_images
          expect(page).to have_current_path(idv_ssn_url)

          visit idv_document_capture_path

          expect(page).to have_current_path(idv_session_errors_rate_limited_path)
        end
      end
    end

    it 'catches network connection errors on post_front_image', allow_browser_log: true do
      DocAuth::Mock::DocAuthMockClient.mock_response!(
        method: :post_front_image,
        response: DocAuth::Response.new(
          success: false,
          errors: { network: I18n.t('doc_auth.errors.general.network_error') },
        ),
      )

      attach_and_submit_images

      expect(page).to have_current_path(idv_document_capture_url)
      expect(page).to have_content(I18n.t('doc_auth.errors.general.network_error'))
    end

    it 'does not track state if state tracking is disabled' do
      allow(IdentityConfig.store).to receive(:state_tracking_enabled).and_return(false)
      attach_and_submit_images

      expect(DocAuthLog.find_by(user_id: @user.id).state).to be_nil
    end
  end

  context 'standard desktop passport flow', allow_browser_log: true do
    before do
      allow(IdentityConfig.store).to receive(:doc_auth_passports_enabled).and_return(true)
      allow(IdentityConfig.store).to receive(:doc_auth_passports_percent).and_return(100)
      stub_request(:get, IdentityConfig.store.dos_passport_composite_healthcheck_endpoint)
        .to_return({ status: 200, body: { status: 'UP' }.to_json })
      reload_ab_tests
      sign_in_and_2fa_user(@user)
      complete_doc_auth_steps_before_hybrid_handoff_step
    end

    after do
      reload_ab_tests
    end

    it 'shows only one image on review step if passport selected' do
      expect(page).to have_content(t('doc_auth.headings.upload_from_computer'))
      click_on t('forms.buttons.upload_photos')
      expect(page).to have_current_path(idv_choose_id_type_url)
      choose(t('doc_auth.forms.id_type_preference.passport'))
      click_on t('forms.buttons.continue')
      expect(page).to have_current_path(idv_document_capture_url)
      # Attach fail images and then continue to retry
      attach_passport_image(
        Rails.root.join(
          'spec', 'fixtures',
          'passport_bad_mrz_credential.yml'
        ),
      )
      submit_images
      expect(page).to have_current_path(idv_document_capture_url)
      click_on t('idv.failure.button.warning')
      expect(page).to have_content(t('doc_auth.headings.document_capture_passport'))
      expect(page).not_to have_content(t('doc_auth.headings.document_capture_back'))
      expect(page).to have_content(t('doc_auth.headings.review_issues_passport'))
      expect(page).to have_content(t('doc_auth.info.review_passport'))
    end
  end

  context 'standard mobile passport flow', allow_browser_log: true do
    before do
      allow(IdentityConfig.store).to receive(:doc_auth_passports_enabled).and_return(true)
      allow(IdentityConfig.store).to receive(:doc_auth_passports_percent).and_return(100)
      stub_request(:get, IdentityConfig.store.dos_passport_composite_healthcheck_endpoint)
        .to_return({ status: 200, body: { status: 'UP' }.to_json })
      reload_ab_tests
    end

    after do
      reload_ab_tests
    end

    it 'shows only one image on review step if passport selected' do
      perform_in_browser(:mobile) do
        sign_in_and_2fa_user(@user)
        complete_doc_auth_steps_before_document_capture_step
        expect(page).to have_current_path(idv_choose_id_type_url)
        choose(t('doc_auth.forms.id_type_preference.passport'))
        click_on t('forms.buttons.continue')
        expect(page).to have_current_path(idv_document_capture_url)
        # Attach fail images and then continue to retry
        attach_passport_image(
          Rails.root.join(
            'spec', 'fixtures',
            'passport_bad_mrz_credential.yml'
          ),
        )
        submit_images
        expect(page).to have_current_path(idv_document_capture_url)
        click_on t('idv.failure.button.warning')
        expect(page).to have_content(t('doc_auth.headings.document_capture_passport'))
        expect(page).not_to have_content(t('doc_auth.headings.document_capture_back'))
        expect(page).to have_content(t('doc_auth.headings.review_issues_passport'))
        expect(page).to have_content(t('doc_auth.info.review_passport'))
      end
    end
  end

  context 'standard mobile flow' do
    it 'proceeds to the next page with valid info' do
      perform_in_browser(:mobile) do
        visit_idp_from_oidc_sp_with_ial2
        sign_in_and_2fa_user(@user)
        complete_doc_auth_steps_before_document_capture_step

        expect(page).to have_current_path(idv_document_capture_url)
        expect_step_indicator_current_step(t('step_indicator.flows.idv.verify_id'))
        expect(page).not_to have_content(t('doc_auth.headings.document_capture_selfie'))

        # doc auth is successful while liveness is not req'd
        use_id_image('ial2_test_credential_no_liveness.yml')
        submit_images

        expect(page).to have_current_path(idv_ssn_url)
        expect_costing_for_document
        expect(DocAuthLog.find_by(user_id: @user.id).state).to eq('NY')

        fill_out_ssn_form_ok
        click_idv_continue
        complete_verify_step
        expect(page).to have_current_path(idv_phone_url)
      end
    end
  end
  context 'selfie check' do
    before do
      allow(IdentityConfig.store).to receive(:use_vot_in_sp_requests).and_return(true)
    end

    context 'when a selfie is not requested by SP' do
      it 'proceeds to the next page with valid info, excluding a selfie image' do
        perform_in_browser(:mobile) do
          visit_idp_from_oidc_sp_with_ial2
          sign_in_and_2fa_user(@user)
          complete_doc_auth_steps_before_document_capture_step

          expect(page).to have_current_path(idv_document_capture_url)
          expect(page).not_to have_content(t('doc_auth.headings.document_capture_selfie'))

          expect_step_indicator_current_step(t('step_indicator.flows.idv.verify_id'))

          attach_images
          submit_images

          expect(page).to have_current_path(idv_ssn_url)
          expect_costing_for_document
          expect(DocAuthLog.find_by(user_id: @user.id).state).to eq('MT')

          expect(page).to have_current_path(idv_ssn_url)
          fill_out_ssn_form_ok
          click_idv_continue
          complete_verify_step
          # expect(page).to have_content(t('doc_auth.headings.document_capture_selfie'))
          expect(page).to have_current_path(idv_phone_url)
        end
      end
    end

    context 'when a selfie is required by the SP' do
      context 'on mobile platform', allow_browser_log: true do
        before do
          # mock mobile device as cameraCapable, this allows us to process
          allow_any_instance_of(ActionController::Parameters)
            .to receive(:[]).and_wrap_original do |impl, param_name|
            param_name.to_sym == :skip_hybrid_handoff ? '' : impl.call(param_name)
          end
        end

        context 'with a passing selfie' do
          it 'proceeds to the next page with valid info, including a selfie image' do
            perform_in_browser(:mobile) do
              visit_idp_from_oidc_sp_with_ial2(facial_match_required: true)
              sign_in_and_2fa_user(@user)
              complete_doc_auth_steps_before_document_capture_step

              expect(page).to have_current_path(idv_document_capture_url)
              expect(max_capture_attempts_before_native_camera.to_i)
                .to eq(ActiveSupport::Duration::SECONDS_PER_HOUR)
              expect(max_submission_attempts_before_native_camera.to_i)
                .to eq(ActiveSupport::Duration::SECONDS_PER_HOUR)
              expect_step_indicator_current_step(t('step_indicator.flows.idv.verify_id'))
              expect(page).to have_text(t('doc_auth.headings.document_capture'))
              attach_images
              click_continue
              expect_doc_capture_selfie_subheader
              click_button 'Take photo'
              attach_selfie
              submit_images

              expect(page).to have_current_path(idv_ssn_url)
              expect_costing_for_document
              expect(DocAuthLog.find_by(user_id: @user.id).state).to eq('MT')

              expect(page).to have_current_path(idv_ssn_url)
              fill_out_ssn_form_ok
              click_idv_continue
              complete_verify_step
              expect(page).to have_current_path(idv_phone_url)
            end
          end
        end

        context 'documents or selfie with error is uploaded' do
          shared_examples 'it has correct error displays' do
            # when there are multiple doc auth errors on front and back
            it 'shows the correct error message for the given error' do
              perform_in_browser(:mobile) do
                click_continue
                use_id_image('ial2_test_credential_multiple_doc_auth_failures_both_sides.yml')
                click_continue
                click_button 'Take photo'
                click_idv_submit_default
                expect(page).not_to have_content(t('doc_auth.headings.capture_complete'))
                expect(page).not_to have_content(t('doc_auth.errors.rate_limited_heading'))
                expect(page).to have_title(t('doc_auth.headings.selfie_capture'))

                use_selfie_image('ial2_test_credential_multiple_doc_auth_failures_both_sides.yml')
                submit_images
                expect_rate_limited_header(true)

                expect_try_taking_new_pictures
                expect_review_issues_body_message('doc_auth.errors.general.no_liveness')
                expect_rate_limit_warning(max_attempts - 1)

                expect_to_try_again
                expect_resubmit_page_h1_copy

                expect_resubmit_page_body_copy('doc_auth.errors.general.no_liveness')
                expect_resubmit_page_inline_error_messages(2)
                expect_resubmit_page_inline_selfie_error_message(false)

                # Wrong doc type is uploaded
                use_id_image('ial2_test_credential_wrong_doc_type.yml')

                use_selfie_image('ial2_test_portrait_match_success.yml')
                submit_images

                expect_rate_limited_header(true)
                expect_try_taking_new_pictures(false)
                # eslint-disable-next-line
                expect_review_issues_body_message(
                  'doc_auth.errors.rate_limited_heading',
                )
                expect_review_issues_body_message('doc_auth.errors.doc.doc_type_check')
                expect_rate_limit_warning(max_attempts - 2)

                expect_to_try_again
                expect_resubmit_page_h1_copy

                expect_review_issues_body_message('doc_auth.errors.general.fallback_field_level')
                expect_resubmit_page_inline_selfie_error_message(false)

                # when there are multiple front doc auth errors
                use_id_image(
                  'ial2_test_credential_multiple_doc_auth_failures_front_side_only.yml',
                )

                use_selfie_image(
                  'ial2_test_credential_multiple_doc_auth_failures_front_side_only.yml',
                )
                submit_images

                expect_rate_limited_header(true)
                expect_try_taking_new_pictures(false)
                expect_review_issues_body_message(
                  'doc_auth.errors.general.multiple_front_id_failures',
                )
                expect_rate_limit_warning(max_attempts - 3)

                expect_to_try_again
                expect_resubmit_page_h1_copy

                expect_resubmit_page_body_copy(
                  'doc_auth.errors.general.multiple_front_id_failures',
                )
                expect_resubmit_page_inline_error_messages(1)
                expect_resubmit_page_inline_selfie_error_message(false)

                # when there are multiple back doc auth errors
                use_id_image(
                  'ial2_test_credential_multiple_doc_auth_failures_back_side_only.yml',
                )

                use_selfie_image(
                  'ial2_test_credential_multiple_doc_auth_failures_back_side_only.yml',
                )
                submit_images

                expect_rate_limited_header(true)
                expect_try_taking_new_pictures(false)
                expect_review_issues_body_message(
                  'doc_auth.errors.general.multiple_back_id_failures',
                )
                expect_rate_limit_warning(max_attempts - 4)

                expect_to_try_again
                expect_resubmit_page_h1_copy

                expect_resubmit_page_body_copy(
                  'doc_auth.errors.general.multiple_back_id_failures',
                )
                expect_resubmit_page_inline_error_messages(1)
                expect_resubmit_page_inline_selfie_error_message(false)

                # attention barcode with invalid pii is uploaded
                use_id_image('ial2_test_credential_barcode_attention_no_address.yml')
                click_continue
                use_selfie_image('ial2_test_portrait_match_success.yml')
                submit_images

                expect(page).to have_content(t('doc_auth.errors.alerts.address_check'))
                expect(page).to have_current_path(idv_document_capture_path)

                click_try_again

                # And finally, after lots of errors, we can still succeed
                attach_images
                submit_images

                expect(page).to have_current_path(idv_ssn_path)
              end
            end
          end

          context 'IPP enabled' do
            let(:ipp_service_provider) do
              create(:service_provider, :active, :in_person_proofing_enabled)
            end

            before do
              allow(IdentityConfig.store).to receive(:in_person_proofing_enabled).and_return(true)
              allow(IdentityConfig.store).to receive(
                :in_person_proofing_opt_in_enabled,
              ).and_return(true)
              allow_any_instance_of(ServiceProvider).to receive(
                :in_person_proofing_enabled,
              ).and_return(true)
              allow(IdentityConfig.store).to receive(:doc_auth_max_attempts).and_return(99)
              perform_in_browser(:mobile) do
                visit_idp_from_sp_with_ial2(
                  :oidc,
                  **{ client_id: ipp_service_provider.issuer,
                      facial_match_required: true },
                )
                sign_in_and_2fa_user(@user)
                complete_up_to_how_to_verify_step_for_opt_in_ipp
              end
            end

            it_should_behave_like 'it has correct error displays'
          end

          context 'IPP not enabled' do
            before do
              allow(IdentityConfig.store).to receive(:doc_auth_max_attempts).and_return(99)
              perform_in_browser(:mobile) do
                visit_idp_from_oidc_sp_with_ial2(facial_match_required: true)
                sign_in_and_2fa_user(@user)
                complete_doc_auth_steps_before_document_capture_step
              end
            end

            it_should_behave_like 'it has correct error displays'
          end
        end

        context 'when selfie check is not enabled (flag off, and/or in production)' do
          it 'proceeds to the next page with valid info, excluding a selfie image' do
            perform_in_browser(:mobile) do
              visit_idp_from_oidc_sp_with_ial2
              sign_in_and_2fa_user(@user)
              complete_doc_auth_steps_before_document_capture_step

              expect(page).to have_current_path(idv_document_capture_url)
              expect(max_capture_attempts_before_native_camera).to eq(
                IdentityConfig.store.doc_auth_max_capture_attempts_before_native_camera.to_s,
              )
              expect(page).not_to have_content(t('doc_auth.headings.document_capture_selfie'))

              expect_step_indicator_current_step(t('step_indicator.flows.idv.verify_id'))

              expect(page).not_to have_content(t('doc_auth.headings.document_capture_selfie'))
              attach_images
              submit_images

              expect(page).to have_current_path(idv_ssn_url)
              expect_costing_for_document
              expect(DocAuthLog.find_by(user_id: @user.id).state).to eq('MT')

              expect(page).to have_current_path(idv_ssn_url)
              fill_out_ssn_form_ok
              click_idv_continue
              complete_verify_step
              expect(page).to have_current_path(idv_phone_url)
            end
          end
        end
      end

      context 'on desktop' do
        let(:desktop_selfie_mode) { false }

        before do
          allow(IdentityConfig.store).to receive(:doc_auth_selfie_desktop_test_mode)
            .and_return(desktop_selfie_mode)
        end

        describe 'when desktop selfie not allowed' do
          it 'can only proceed to link sent page' do
            perform_in_browser(:desktop) do
              visit_idp_from_oidc_sp_with_ial2(facial_match_required: true)
              sign_in_and_2fa_user(@user)
              complete_doc_auth_steps_before_hybrid_handoff_step
              # we still have option to continue
              expect(page).to have_current_path(idv_hybrid_handoff_path)
              expect(page).to have_content(t('doc_auth.headings.how_to_verify'))
              expect(page).not_to have_content(t('doc_auth.info.upload_from_computer'))
              click_on t('forms.buttons.send_link')
              expect(page).to have_current_path(idv_link_sent_path)
            end
          end
        end

        describe 'when desktop selfie is allowed' do
          let(:desktop_selfie_mode) { true }

          it 'proceed to the next page with valid info, including a selfie image' do
            perform_in_browser(:desktop) do
              visit_idp_from_oidc_sp_with_ial2(facial_match_required: true)
              sign_in_and_2fa_user(@user)
              complete_doc_auth_steps_before_hybrid_handoff_step
              # we still have option to continue on handoff, since it's desktop no skip_hand_off
              expect(page).to have_current_path(idv_hybrid_handoff_path)
              expect(page).to have_content(t('doc_auth.headings.how_to_verify'))
              expect(page).to have_content(t('doc_auth.info.upload_from_computer'))
              click_on t('forms.buttons.upload_photos')
              expect(page).to have_current_path(idv_document_capture_url)
              expect_step_indicator_current_step(t('step_indicator.flows.idv.verify_id'))
              expect(page).to have_text(t('doc_auth.headings.document_capture'))
              attach_images
              click_continue
              expect_doc_capture_selfie_subheader
              click_button 'Take photo'
              attach_selfie
              submit_images

              expect(page).to have_current_path(idv_ssn_url)
              expect_costing_for_document
              expect(DocAuthLog.find_by(user_id: @user.id).state).to eq('MT')

              expect(page).to have_current_path(idv_ssn_url)
              fill_out_ssn_form_ok
              click_idv_continue
              complete_verify_step
              expect(page).to have_current_path(idv_phone_url)
            end
          end

          context 'when ipp is enabled' do
            let(:in_person_doc_auth_button_enabled) { true }
            let(:sp_ipp_enabled) { true }

            before do
              allow(IdentityConfig.store).to receive(:in_person_doc_auth_button_enabled)
                .and_return(in_person_doc_auth_button_enabled)
              allow(IdentityConfig.store).to receive(:in_person_proofing_enabled)
                .and_return(true)
              allow(IdentityConfig.store).to receive(:in_person_proofing_opt_in_enabled)
                .and_return(true)
              allow(Idv::InPersonConfig).to receive(:enabled_for_issuer?).with(anything)
                .and_return(sp_ipp_enabled)
            end

            describe 'when ipp is selected' do
              it 'proceed to the next page and start ipp' do
                perform_in_browser(:desktop) do
                  visit_idp_from_oidc_sp_with_ial2(facial_match_required: true)
                  sign_in_and_2fa_user(@user)
                  complete_doc_auth_steps_before_hybrid_handoff_step
                  # still have option to continue handoff, since it's desktop no skip_hand_off
                  expect(page).to have_current_path(idv_hybrid_handoff_path)
                  expect(page).to have_content(t('doc_auth.headings.how_to_verify'))
                  click_on t('forms.buttons.continue_ipp')
                  expect(page).to have_current_path(
                    idv_document_capture_path({ step: 'hybrid_handoff' }),
                  )
                  expect_step_indicator_current_step(
                    t('step_indicator.flows.idv.find_a_post_office'),
                  )
                  expect_doc_capture_page_header(t('in_person_proofing.headings.prepare'))
                end
              end
            end
          end
        end
      end
    end
  end

  def expect_rate_limited_header(expected_to_be_present)
    review_issues_h1_heading = strip_tags(t('doc_auth.errors.rate_limited_heading'))
    if expected_to_be_present
      expect(page).to have_content(review_issues_h1_heading)
    else
      expect(page).not_to have_content(review_issues_h1_heading)
    end
  end

  def expect_try_taking_new_pictures(expected_to_be_present = true)
    expected_message = strip_tags(
      t('doc_auth.errors.rate_limited_subheading'),
    )
    if expected_to_be_present
      expect(page).to have_content expected_message
    else
      expect(page).not_to have_content expected_message
    end
  end

  def expect_review_issues_body_message(translation_key)
    review_issues_body_message = strip_tags(t(translation_key))
    expect(page).to have_content(review_issues_body_message)
  end

  def expect_resubmit_page_h1_copy
    resubmit_page_h1_copy = strip_tags(t('doc_auth.headings.review_issues'))
    expect(page).to have_content(resubmit_page_h1_copy)
  end

  def expect_resubmit_page_body_copy(translation_key)
    resubmit_page_body_copy = strip_tags(t(translation_key))
    expect(page).to have_content(resubmit_page_body_copy)
  end

  def expect_resubmit_page_inline_error_messages(expected_count)
    resubmit_page_inline_error_messages = strip_tags(
      t('doc_auth.errors.general.fallback_field_level'),
    )
    expect(page).to have_content(resubmit_page_inline_error_messages).exactly(expected_count)
  end

  def expect_resubmit_page_inline_selfie_error_message(should_be_present)
    resubmit_page_inline_selfie_error_message = strip_tags(
      t('doc_auth.errors.general.selfie_failure'),
    )
    if should_be_present
      expect(page).to have_content(resubmit_page_inline_selfie_error_message)
    else
      expect(page).not_to have_content(resubmit_page_inline_selfie_error_message)
    end
  end

  def use_id_image(filename)
    expect(page).to have_content('Front of your ID')
    attach_images Rails.root.join('spec', 'fixtures', filename)
  end

  def use_selfie_image(filename)
    attach_selfie Rails.root.join('spec', 'fixtures', filename)
  end

  def expect_costing_for_document
    %i[acuant_front_image acuant_back_image acuant_result].each do |cost_type|
      expect(costing_for(cost_type)).to be_present
    end
  end

  def costing_for(cost_type)
    SpCost.where(ial: 2, issuer: 'urn:gov:gsa:openidconnect:sp:server', cost_type: cost_type.to_s)
  end
end

RSpec.feature 'direct access to IPP on desktop', :js do
  include IdvStepHelper
  include DocAuthHelper

  context 'before handoff page' do
    let(:sp_ipp_enabled) { true }
    let(:in_person_proofing_opt_in_enabled) { true }
    let(:facial_match_required) { true }
    let(:user) { user_with_2fa }

    before do
      service_provider = create(:service_provider, :active, :in_person_proofing_enabled)
      allow(IdentityConfig.store).to receive(:doc_auth_selfie_desktop_test_mode).and_return(false)
      allow(IdentityConfig.store).to receive(:in_person_proofing_enabled).and_return(true)
      allow(IdentityConfig.store).to receive(:in_person_proofing_opt_in_enabled).and_return(
        in_person_proofing_opt_in_enabled,
      )
      allow_any_instance_of(ServiceProvider).to receive(:in_person_proofing_enabled)
        .and_return(false)
      visit_idp_from_sp_with_ial2(
        :oidc,
        **{ client_id: service_provider.issuer,
            facial_match_required: facial_match_required },
      )
      sign_in_via_branded_page(user)
      complete_doc_auth_steps_before_agreement_step

      visit idv_document_capture_path(step: 'hybrid_handoff')
    end

    context 'when selfie is enabled' do
      it 'redirects back to agreement page' do
        expect(page).to have_current_path(idv_agreement_path)
      end
    end

    context 'when selfie is disabled' do
      let(:facial_match_required) { false }

      it 'redirects back to agreement page' do
        expect(page).to have_current_path(idv_agreement_path)
      end
    end
  end
end
