require 'rails_helper'

RSpec.feature 'document capture step', :js, allowed_extra_analytics: [:*] do
  include IdvStepHelper
  include DocAuthHelper
  include DocCaptureHelper
  include ActionView::Helpers::DateHelper

  let(:max_attempts) { IdentityConfig.store.doc_auth_max_attempts }
  let(:enable_exit_question) { true }
  before(:each) do
    allow_any_instance_of(ApplicationController).to receive(:analytics).and_return(@fake_analytics)
    allow_any_instance_of(ServiceProviderSession).to receive(:sp_name).and_return(@sp_name)
    allow(IdentityConfig.store).to receive(:doc_auth_exit_question_section_enabled).
      and_return(enable_exit_question)

    visit_idp_from_oidc_sp_with_ial2
    sign_in_and_2fa_user(@user)
  end

  before(:all) do
    @user = user_with_2fa
    @fake_analytics = FakeAnalytics.new
    @sp_name = 'Test SP'
  end

  after(:all) do
    @user.destroy
    @fake_analytics = ''
    @sp_name = ''
  end

  context 'standard desktop flow' do
    before do
      complete_doc_auth_steps_before_document_capture_step
    end

    context 'wrong doc type is uploaded', allow_browser_log: true do
      it 'try again and page show doc type inline error message' do
        attach_images(
          Rails.root.join(
            'spec', 'fixtures',
            'ial2_test_credential_wrong_doc_type.yml'
          ),
        )
        submit_images
        message = strip_tags(t('errors.doc_auth.doc_type_not_supported_heading'))
        expect(page).to have_content(message)
        detail_message = strip_tags(t('doc_auth.errors.doc.doc_type_check'))
        security_message = strip_tags(
          t(
            'idv.warning.attempts_html',
            count: IdentityConfig.store.doc_auth_max_attempts - 1,
          ),
        )
        expect(page).to have_content(detail_message << ' ' << security_message)
        expect(page).to have_current_path(idv_document_capture_path)
        click_try_again
        expect(page).to have_current_path(idv_document_capture_path)
        inline_error = strip_tags(t('doc_auth.errors.card_type'))
        expect(page).to have_content(inline_error)
      end
    end

    context 'attention barcode with invalid pii is uploaded', allow_browser_log: true do
      let(:desktop_selfie_mode) { false }
      # test disabled desktop selfie mode allows upload for doc auth w/o selfie
      before do
        allow(IdentityConfig.store).to receive(:doc_auth_selfie_desktop_test_mode).
          and_return(desktop_selfie_mode)
      end
      it 'try again and page show doc type inline error message' do
        attach_images(
          Rails.root.join(
            'spec', 'fixtures',
            'ial2_test_credential_barcode_attention_no_address.yml'
          ),
        )
        submit_images

        expect(page).to have_content(t('doc_auth.errors.alerts.address_check'))
        expect(page).to have_current_path(idv_document_capture_path)

        click_try_again
        attach_images
        submit_images
        expect(page).to have_current_path(idv_ssn_path)
      end
    end

    context 'rate limits calls to backend docauth vendor', allow_browser_log: true do
      let(:fake_attempts_tracker) { IrsAttemptsApiTrackingHelper::FakeAttemptsTracker.new }
      before do
        allow_any_instance_of(ApplicationController).to receive(
          :irs_attempts_api_tracker,
        ).and_return(fake_attempts_tracker)
        allow(fake_attempts_tracker).to receive(:idv_document_upload_rate_limited)
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
          message = strip_tags(t('errors.doc_auth.rate_limited_text_html', timeout: timeout))
          expect(page).to have_content(message)
          expect(page).to have_current_path(idv_session_errors_rate_limited_path)
        end
      end

      it 'logs the rate limited analytics event for doc_auth' do
        attach_and_submit_images
        expect(@fake_analytics).to have_logged_event(
          'Rate Limit Reached',
          limiter_type: :idv_doc_auth,
        )
      end

      it 'logs irs attempts event for rate limiting' do
        attach_and_submit_images
        expect(fake_attempts_tracker).to have_received(:idv_document_upload_rate_limited)
      end

      context 'successfully processes image on last attempt' do
        before do
          DocAuth::Mock::DocAuthMockClient.reset!
        end

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

    it 'return to sp when click on exit link', :js do
      click_sp_exit_link(sp_name: @sp_name)
      expect(current_url).to start_with('http://localhost:7654/auth/result?error=access_denied')
    end

    it 'logs event and return to sp when click on submit and exit button', :js do
      click_submit_exit_button
      expect(@fake_analytics).to have_logged_event(
        'Frontend: IdV: exit optional questions',
        hash_including(:ids),
      )
      expect(current_url).to start_with('http://localhost:7654/auth/result?error=access_denied')
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
        attach_images(
          Rails.root.join(
            'spec', 'fixtures',
            'ial2_test_credential_no_liveness.yml'
          ),
        )
        submit_images

        expect(page).to have_current_path(idv_ssn_url)
        expect_costing_for_document
        expect(DocAuthLog.find_by(user_id: @user.id).state).to eq('NY')

        expect(page).to have_current_path(idv_ssn_url)
        fill_out_ssn_form_ok
        click_idv_continue
        complete_verify_step
        expect(page).to have_current_path(idv_phone_url)
      end
    end
  end

  context 'selfie check' do
    let(:selfie_check_enabled) { true }
    before do
      expect(FeatureManagement).to receive(:idv_allow_selfie_check?).at_least(:once).
        and_return(selfie_check_enabled)
      complete_doc_auth_steps_before_document_capture_step
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
          expect(page).to have_current_path(idv_phone_url)
        end
      end
    end

    context 'when a selfie is required by the SP' do
      before do
        allow_any_instance_of(FederatedProtocols::Oidc).
          to receive(:biometric_comparison_required?).
          and_return(true)
      end

      context 'on mobile platform', allow_browser_log: true do
        before do
          # mock mobile device as cameraCapable, this allows us to process
          allow_any_instance_of(ActionController::Parameters).
            to receive(:[]).and_wrap_original do |impl, param_name|
            param_name.to_sym == :skip_hybrid_handoff ? '' : impl.call(param_name)
          end
        end

        context 'with a passing selfie' do
          it 'proceeds to the next page with valid info, including a selfie image' do
            perform_in_browser(:mobile) do
              visit_idp_from_oidc_sp_with_ial2(biometric_comparison_required: true)
              sign_in_and_2fa_user(@user)
              complete_doc_auth_steps_before_document_capture_step

              expect(page).to have_current_path(idv_document_capture_url)
              expect(max_capture_attempts_before_native_camera.to_i).
                to eq(ActiveSupport::Duration::SECONDS_PER_HOUR)
              expect(max_submission_attempts_before_native_camera.to_i).
                to eq(ActiveSupport::Duration::SECONDS_PER_HOUR)
              expect_step_indicator_current_step(t('step_indicator.flows.idv.verify_id'))
              expect_doc_capture_page_header(t('doc_auth.headings.document_capture_with_selfie'))
              expect_doc_capture_id_subheader
              expect_doc_capture_selfie_subheader
              attach_liveness_images
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

        context 'selfie with error is uploaded' do
          before do
            allow(IdentityConfig.store).to receive(:doc_auth_max_attempts).and_return(99)

            allow_any_instance_of(FederatedProtocols::Oidc).
              to receive(:biometric_comparison_required?).
              and_return(true)
            perform_in_browser(:mobile) do
              visit_idp_from_oidc_sp_with_ial2(biometric_comparison_required: true)
              sign_in_and_2fa_user(@user)
              complete_doc_auth_steps_before_document_capture_step
            end
          end

          it 'shows the correct error message for the given error' do
            # when the only error is a doc auth error

            perform_in_browser(:mobile) do
              attach_images(
                Rails.root.join(
                  'spec', 'fixtures',
                  'ial2_test_credential_doc_auth_fail_selfie_pass.yml'
                ),
              )
              attach_selfie(
                Rails.root.join(
                  'spec', 'fixtures',
                  'ial2_test_credential_doc_auth_fail_selfie_pass.yml'
                ),
              )

              submit_images

              h1_error_message = strip_tags(t('errors.doc_auth.rate_limited_heading'))
              expect(page).to have_content(h1_error_message)

              body_error_message = strip_tags(t('doc_auth.errors.dpi.top_msg'))
              expect(page).to have_content(body_error_message)

              click_try_again
              expect(page).to have_current_path(idv_document_capture_path)

              inline_error_message = strip_tags(t('doc_auth.errors.dpi.failed_short'))
              expect(page).to have_content(inline_error_message)

              expect(page).to have_current_path(idv_document_capture_url)

              # when doc auth result passes but liveness fails

              attach_images(
                Rails.root.join(
                  'spec', 'fixtures',
                  'ial2_test_credential_no_liveness.yml'
                ),
              )
              attach_selfie(
                Rails.root.join(
                  'spec', 'fixtures',
                  'ial2_test_credential_no_liveness.yml'
                ),
              )

              submit_images

              h1_error_message = strip_tags(
                t('errors.doc_auth.selfie_not_live_or_poor_quality_heading'),
              )
              expect(page).to have_content(h1_error_message)

              body_error_message = strip_tags(t('doc_auth.errors.alerts.selfie_not_live'))
              expect(page).to have_content(body_error_message)

              click_try_again
              expect(page).to have_current_path(idv_document_capture_path)

              # inline error to be fixed in lg-12999

              # when there are both doc auth errors and liveness errors

              attach_images(
                Rails.root.join(
                  'spec', 'fixtures',
                  'ial2_test_credential_doc_auth_fail_and_no_liveness.yml'
                ),
              )
              attach_selfie(
                Rails.root.join(
                  'spec', 'fixtures',
                  'ial2_test_credential_doc_auth_fail_and_no_liveness.yml'
                ),
              )

              submit_images

              h1_error_message = strip_tags(t('errors.doc_auth.rate_limited_heading'))
              expect(page).to have_content(h1_error_message)

              body_error_message = strip_tags(t('doc_auth.errors.dpi.top_msg'))
              expect(page).to have_content(body_error_message)

              click_try_again
              expect(page).to have_current_path(idv_document_capture_path)

              inline_error_message = strip_tags(t('doc_auth.errors.dpi.failed_short'))
              expect(page).to have_content(inline_error_message)

              # when there are both doc auth errors and face match errors

              attach_images(
                Rails.root.join(
                  'spec', 'fixtures',
                  'ial2_test_credential_doc_auth_fail_face_match_fail.yml'
                ),
              )
              attach_selfie(
                Rails.root.join(
                  'spec', 'fixtures',
                  'ial2_test_credential_doc_auth_fail_face_match_fail.yml'
                ),
              )

              submit_images

              h1_error_message = strip_tags(t('errors.doc_auth.rate_limited_heading'))
              expect(page).to have_content(h1_error_message)

              body_error_message = strip_tags(t('doc_auth.errors.dpi.top_msg'))
              expect(page).to have_content(body_error_message)

              click_try_again
              expect(page).to have_current_path(idv_document_capture_path)

              inline_error_message = strip_tags(t('doc_auth.errors.dpi.failed_short'))
              expect(page).to have_content(inline_error_message)

              # when doc auth result and liveness pass but face match fails

              attach_images(
                Rails.root.join(
                  'spec', 'fixtures',
                  'ial2_test_portrait_match_failure.yml'
                ),
              )
              attach_selfie(
                Rails.root.join(
                  'spec', 'fixtures',
                  'ial2_test_portrait_match_failure.yml'
                ),
              )

              submit_images

              h1_error_message = strip_tags(t('errors.doc_auth.selfie_fail_heading'))
              expect(page).to have_content(h1_error_message)

              body_error_message = strip_tags(t('doc_auth.errors.general.selfie_failure'))
              expect(page).to have_content(body_error_message)

              click_try_again
              expect(page).to have_current_path(idv_document_capture_path)

              inline_error_message = strip_tags(
                t('doc_auth.errors.general.multiple_front_id_failures'),
              )
              expect(page).to have_content(inline_error_message)

              # when there is a doc auth error on one side of the ID and face match errors

              attach_images(
                Rails.root.join(
                  'spec', 'fixtures',
                  'ial2_test_credential_back_fail_doc_auth_face_match_errors.yml'
                ),
              )
              attach_selfie(
                Rails.root.join(
                  'spec', 'fixtures',
                  'ial2_test_credential_back_fail_doc_auth_face_match_errors.yml'
                ),
              )

              submit_images

              h1_error_message = strip_tags(t('errors.doc_auth.rate_limited_heading'))
              expect(page).to have_content(h1_error_message)

              body_error_message = strip_tags(t('doc_auth.errors.alerts.barcode_content_check'))
              expect(page).to have_content(body_error_message)

              click_try_again
              expect(page).to have_current_path(idv_document_capture_path)

              inline_error_message = strip_tags(t('doc_auth.errors.general.fallback_field_level'))
              expect(page).to have_content(inline_error_message)

              # when there is a doc auth error on one side of the ID and a liveness error

              attach_images(
                Rails.root.join(
                  'spec', 'fixtures',
                  'ial2_test_credential_back_fail_doc_auth_liveness_errors.yml'
                ),
              )
              attach_selfie(
                Rails.root.join(
                  'spec', 'fixtures',
                  'ial2_test_credential_back_fail_doc_auth_liveness_errors.yml'
                ),
              )

              submit_images

              h1_error_message = strip_tags(t('errors.doc_auth.rate_limited_heading'))
              expect(page).to have_content(h1_error_message)

              body_error_message = strip_tags(t('doc_auth.errors.alerts.barcode_content_check'))
              expect(page).to have_content(body_error_message)

              click_try_again
              expect(page).to have_current_path(idv_document_capture_path)

              inline_error_message = strip_tags(t('doc_auth.errors.general.fallback_field_level'))
              expect(page).to have_content(inline_error_message)

              # when doc auth result is "attention" and face match errors

              attach_images(
                Rails.root.join(
                  'spec', 'fixtures',
                  'ial2_test_credential_doc_auth_attention_face_match_fail.yml'
                ),
              )
              attach_selfie(
                Rails.root.join(
                  'spec', 'fixtures',
                  'ial2_test_credential_doc_auth_attention_face_match_fail.yml'
                ),
              )

              submit_images

              h1_error_message = strip_tags(t('errors.doc_auth.rate_limited_heading'))
              expect(page).to have_content(h1_error_message)

              body_error_message = strip_tags(t('doc_auth.errors.dpi.top_msg_plural'))
              expect(page).to have_content(body_error_message)

              click_try_again
              expect(page).to have_current_path(idv_document_capture_path)

              inline_error_message = strip_tags(t('doc_auth.errors.general.fallback_field_level'))
              expect(page).to have_content(inline_error_message)

              # when doc auth passes but there are both liveness errors and face match errors

              attach_images(
                Rails.root.join(
                  'spec', 'fixtures',
                  'ial2_test_credential_liveness_fail_face_match_fail.yml'
                ),
              )
              attach_selfie(
                Rails.root.join(
                  'spec', 'fixtures',
                  'ial2_test_credential_liveness_fail_face_match_fail.yml'
                ),
              )

              submit_images

              h1_error_message = strip_tags(
                t('errors.doc_auth.selfie_not_live_or_poor_quality_heading'),
              )
              expect(page).to have_content(h1_error_message)

              body_error_message = strip_tags(t('doc_auth.errors.alerts.selfie_not_live'))
              expect(page).to have_content(body_error_message)

              click_try_again
              expect(page).to have_current_path(idv_document_capture_path)

              # when doc auth, liveness, and face match pass but PII validation fails

              attach_images(
                Rails.root.join(
                  'spec', 'fixtures',
                  'ial2_test_credential_doc_auth_selfie_pass_pii_fail.yml'
                ),
              )
              attach_selfie(
                Rails.root.join(
                  'spec', 'fixtures',
                  'ial2_test_credential_doc_auth_selfie_pass_pii_fail.yml'
                ),
              )

              submit_images

              h1_error_message = strip_tags(t('errors.doc_auth.rate_limited_heading'))
              expect(page).to have_content(h1_error_message)

              body_error_message = strip_tags(t('doc_auth.errors.alerts.address_check'))
              expect(page).to have_content(body_error_message)

              click_try_again
              expect(page).to have_current_path(idv_document_capture_path)

              inline_error_message = strip_tags(
                t('doc_auth.errors.general.multiple_front_id_failures'),
              )
              expect(page).to have_content(inline_error_message)

              # when there are both face match errors and pii errors

              attach_images(
                Rails.root.join(
                  'spec', 'fixtures',
                  'ial2_test_credential_face_match_fail_and_pii_fail.yml'
                ),
              )
              attach_selfie(
                Rails.root.join(
                  'spec', 'fixtures',
                  'ial2_test_credential_face_match_fail_and_pii_fail.yml'
                ),
              )

              submit_images

              h1_error_message = strip_tags(t('errors.doc_auth.selfie_fail_heading'))
              expect(page).to have_content(h1_error_message)

              body_error_message = strip_tags(t('doc_auth.errors.general.selfie_failure'))
              expect(page).to have_content(body_error_message)

              click_try_again
              expect(page).to have_current_path(idv_document_capture_path)

              inline_error_message = strip_tags(
                t('doc_auth.errors.general.multiple_front_id_failures'),
              )
              expect(page).to have_content(inline_error_message)
            end
          end

          it 'try again and page show no liveness inline error message' do
            visit_idp_from_oidc_sp_with_ial2(biometric_comparison_required: true)
            sign_in_and_2fa_user(@user)
            complete_doc_auth_steps_before_document_capture_step
            attach_images(
              Rails.root.join(
                'spec', 'fixtures',
                'ial2_test_credential_no_liveness.yml'
              ),
            )
            attach_selfie(
              Rails.root.join(
                'spec', 'fixtures',
                'ial2_test_credential_no_liveness.yml'
              ),
            )
            submit_images
            message = strip_tags(t('errors.doc_auth.selfie_not_live_or_poor_quality_heading'))
            expect(page).to have_content(message)
            detail_message = strip_tags(t('doc_auth.errors.alerts.selfie_not_live'))
            security_message = strip_tags(
              t(
                'idv.warning.attempts_html',
                count: IdentityConfig.store.doc_auth_max_attempts - 1,
              ),
            )
            expect(page).to have_content(detail_message << "\n" << security_message)
            review_issues_header = strip_tags(
              t('errors.doc_auth.selfie_not_live_or_poor_quality_heading'),
            )
            expect(page).to have_content(review_issues_header)
            expect(page).to have_current_path(idv_document_capture_path)
            click_try_again
            expect(page).to have_current_path(idv_document_capture_path)
            inline_error = strip_tags(t('doc_auth.errors.general.selfie_failure'))
            expect(page).to have_content(inline_error)
          end

          it 'try again and page show poor quality inline error message' do
            visit_idp_from_oidc_sp_with_ial2(biometric_comparison_required: true)
            sign_in_and_2fa_user(@user)
            complete_doc_auth_steps_before_document_capture_step
            attach_images(
              Rails.root.join(
                'spec', 'fixtures',
                'ial2_test_credential_poor_quality.yml'
              ),
            )
            attach_selfie(
              Rails.root.join(
                'spec', 'fixtures',
                'ial2_test_credential_poor_quality.yml'
              ),
            )
            submit_images
            message = strip_tags(t('errors.doc_auth.selfie_not_live_or_poor_quality_heading'))
            expect(page).to have_content(message)
            detail_message = strip_tags(t('doc_auth.errors.alerts.selfie_poor_quality'))
            security_message = strip_tags(
              t(
                'idv.warning.attempts_html',
                count: IdentityConfig.store.doc_auth_max_attempts - 1,
              ),
            )
            expect(page).to have_content(detail_message << "\n" << security_message)
            review_issues_header = strip_tags(
              t('errors.doc_auth.selfie_not_live_or_poor_quality_heading'),
            )
            expect(page).to have_content(review_issues_header)
            expect(page).to have_current_path(idv_document_capture_path)
            click_try_again
            expect(page).to have_current_path(idv_document_capture_path)
            inline_error = strip_tags(t('doc_auth.errors.general.selfie_failure'))
            expect(page).to have_content(inline_error)
          end

          it 'try again and page show selfie fail inline error message' do
            visit_idp_from_oidc_sp_with_ial2(biometric_comparison_required: true)
            sign_in_and_2fa_user(@user)
            complete_doc_auth_steps_before_document_capture_step
            attach_images(
              Rails.root.join(
                'spec', 'fixtures',
                'ial2_test_portrait_match_failure.yml'
              ),
            )
            attach_selfie(
              Rails.root.join(
                'spec', 'fixtures',
                'ial2_test_portrait_match_failure.yml'
              ),
            )
            submit_images
            message = strip_tags(t('errors.doc_auth.selfie_fail_heading'))
            expect(page).to have_content(message)
            detail_message = strip_tags(t('doc_auth.errors.general.selfie_failure'))
            security_message = strip_tags(
              t(
                'idv.warning.attempts_html',
                count: IdentityConfig.store.doc_auth_max_attempts - 1,
              ),
            )
            expect(page).to have_content(detail_message << "\n" << security_message)
            review_issues_header = strip_tags(
              t('errors.doc_auth.selfie_fail_heading'),
            )
            expect(page).to have_content(review_issues_header)
            expect(page).to have_current_path(idv_document_capture_path)
            click_try_again
            expect(page).to have_current_path(idv_document_capture_path)
            inline_error = strip_tags(t('doc_auth.errors.general.selfie_failure'))
            expect(page).to have_content(inline_error)
          end
        end
        context 'with Attention with Barcode' do
          it 'try again and page show selfie fail inline error message' do
            visit_idp_from_oidc_sp_with_ial2
            sign_in_and_2fa_user(@user)
            complete_doc_auth_steps_before_document_capture_step
            attach_images(
              Rails.root.join(
                'spec', 'fixtures',
                'ial2_test_credential_barcode_attention_liveness_fail.yml'
              ),
            )
            attach_selfie(
              Rails.root.join(
                'spec', 'fixtures',
                'ial2_test_credential_barcode_attention_liveness_fail.yml'
              ),
            )
            submit_images
            message = strip_tags(t('errors.doc_auth.selfie_not_live_or_poor_quality_heading'))
            expect(page).to have_content(message)
            detail_message = strip_tags(t('doc_auth.errors.alerts.selfie_not_live'))
            security_message = strip_tags(
              t(
                'idv.warning.attempts_html',
                count: IdentityConfig.store.doc_auth_max_attempts - 1,
              ),
            )

            expect(page).to have_content(detail_message << "\n" << security_message)
            review_issues_header = strip_tags(
              t('errors.doc_auth.selfie_not_live_or_poor_quality_heading'),
            )
            expect(page).to have_content(review_issues_header)
            expect(page).to have_current_path(idv_document_capture_path)
            click_try_again
            expect(page).to have_current_path(idv_document_capture_path)
            inline_error = strip_tags(t('doc_auth.errors.general.selfie_failure'))
            expect(page).to have_content(inline_error)
          end
        end

        context 'when selfie check is not enabled (flag off, and/or in production)' do
          let(:selfie_check_enabled) { false }
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
          allow(IdentityConfig.store).to receive(:doc_auth_selfie_desktop_test_mode).
            and_return(desktop_selfie_mode)
        end
        describe 'when desktop selfie not allowed' do
          it 'can only proceed to link sent page' do
            perform_in_browser(:desktop) do
              visit_idp_from_oidc_sp_with_ial2(biometric_comparison_required: true)
              sign_in_and_2fa_user(@user)
              complete_doc_auth_steps_before_hybrid_handoff_step
              # we still have option to continue
              expect(page).to have_current_path(idv_hybrid_handoff_path)
              expect(page).to have_content(t('doc_auth.headings.hybrid_handoff_selfie'))
              expect(page).not_to have_content(t('doc_auth.headings.hybrid_handoff'))
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
              visit_idp_from_oidc_sp_with_ial2(biometric_comparison_required: true)
              sign_in_and_2fa_user(@user)
              complete_doc_auth_steps_before_hybrid_handoff_step
              # we still have option to continue on handoff, since it's desktop no skip_hand_off
              expect(page).to have_current_path(idv_hybrid_handoff_path)
              expect(page).to have_content(t('doc_auth.headings.hybrid_handoff_selfie'))
              expect(page).not_to have_content(t('doc_auth.headings.hybrid_handoff'))
              expect(page).to have_content(t('doc_auth.info.upload_from_computer'))
              click_on t('forms.buttons.upload_photos')
              expect(page).to have_current_path(idv_document_capture_url)
              expect_step_indicator_current_step(t('step_indicator.flows.idv.verify_id'))
              expect_doc_capture_page_header(t('doc_auth.headings.document_capture_with_selfie'))
              expect_doc_capture_id_subheader
              expect_doc_capture_selfie_subheader
              attach_liveness_images
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
              allow(IdentityConfig.store).to receive(:in_person_doc_auth_button_enabled).
                and_return(in_person_doc_auth_button_enabled)
              allow(Idv::InPersonConfig).to receive(:enabled_for_issuer?).with(anything).
                and_return(sp_ipp_enabled)
            end
            describe 'when ipp is selected' do
              it 'proceed to the next page and start ipp' do
                perform_in_browser(:desktop) do
                  visit_idp_from_oidc_sp_with_ial2(biometric_comparison_required: true)
                  sign_in_and_2fa_user(@user)
                  complete_doc_auth_steps_before_hybrid_handoff_step
                  # we still have option to continue on handoff, since it's desktop no skip_hand_off
                  expect(page).to have_current_path(idv_hybrid_handoff_path)
                  expect(page).to have_content(t('doc_auth.headings.hybrid_handoff_selfie'))
                  click_on t('in_person_proofing.headings.prepare')
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

  def expect_costing_for_document
    %i[acuant_front_image acuant_back_image acuant_result].each do |cost_type|
      expect(costing_for(cost_type)).to be_present
    end
  end

  def costing_for(cost_type)
    SpCost.where(ial: 2, issuer: 'urn:gov:gsa:openidconnect:sp:server', cost_type: cost_type.to_s)
  end
end

RSpec.feature 'direct access to IPP on desktop', :js, allowed_extra_analytics: [:*] do
  include IdvStepHelper
  include DocAuthHelper
  context 'direct access to IPP before handoff page' do
    let(:in_person_proofing_enabled) { true }
    let(:sp_ipp_enabled) { true }
    let(:in_person_proofing_opt_in_enabled) { true }
    let(:doc_auth_selfie_capture_enabled) { true }
    let(:biometric_comparison_required) { true }
    let(:user) { user_with_2fa }

    before do
      service_provider = create(:service_provider, :active, :in_person_proofing_enabled)
      unless sp_ipp_enabled
        service_provider.in_person_proofing_enabled = false
        service_provider.save!
      end
      allow(IdentityConfig.store).to receive(:doc_auth_selfie_desktop_test_mode).and_return(false)
      allow(IdentityConfig.store).to receive(:in_person_proofing_enabled).and_return(
        in_person_proofing_enabled,
      )
      allow(IdentityConfig.store).to receive(:in_person_proofing_opt_in_enabled).and_return(
        in_person_proofing_opt_in_enabled,
      )
      allow(IdentityConfig.store).to receive(:doc_auth_selfie_capture_enabled).
        and_return(doc_auth_selfie_capture_enabled)
      allow_any_instance_of(ServiceProvider).to receive(:in_person_proofing_enabled).
        and_return(sp_ipp_enabled)
      visit_idp_from_sp_with_ial2(
        :oidc,
        **{ client_id: service_provider.issuer,
            biometric_comparison_required: biometric_comparison_required },
      )
      sign_in_via_branded_page(user)
      complete_doc_auth_steps_before_agreement_step
    end

    shared_examples 'does not allow direct ipp access' do
      it 'redirects back to agreement page' do
        visit idv_document_capture_path(step: 'hybrid_handoff')
        expect(page).to have_current_path(idv_agreement_path)
      end
    end
    context 'when selfie is enabled' do
      it_behaves_like 'does not allow direct ipp access'
    end
    context 'when selfie is disabled' do
      let(:biometric_comparison_required) { false }
      it_behaves_like 'does not allow direct ipp access'
    end
  end
end
