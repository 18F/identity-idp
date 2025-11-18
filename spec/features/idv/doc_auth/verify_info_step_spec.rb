require 'rails_helper'

RSpec.feature 'verify_info step and verify_info_concern', :js do
  include IdvStepHelper
  include DocAuthHelper

  let(:fake_analytics) { FakeAnalytics.new }
  let(:attempts_api_tracker) { AttemptsApiTrackingHelper::FakeAttemptsTracker.new }
  let(:user) { user_with_2fa }

  let(:fake_pii_details) do
    {
      document_state: MOCK_IDV_APPLICANT[:state],
      document_number: MOCK_IDV_APPLICANT[:state_id_number],
      document_issued: MOCK_IDV_APPLICANT[:state_id_issued],
      document_expiration: MOCK_IDV_APPLICANT[:state_id_expiration],
      first_name: MOCK_IDV_APPLICANT[:first_name],
      last_name: MOCK_IDV_APPLICANT[:last_name],
      date_of_birth: MOCK_IDV_APPLICANT[:dob],
      address: MOCK_IDV_APPLICANT[:address1],
    }
  end

  context 'no outage' do
    before do
      allow_any_instance_of(ApplicationController).to receive(:analytics).and_return(fake_analytics)
      allow_any_instance_of(ApplicationController).to receive(:attempts_api_tracker).and_return(
        attempts_api_tracker,
      )
      sign_in_and_2fa_user(user)
      complete_doc_auth_steps_before_ssn_step
    end

    context 'with good ssn' do
      before do
        fill_out_ssn_form_ok
        click_idv_continue
      end

      it 'allows the user to enter in a new address and displays updated info' do
        click_link t('idv.buttons.change_address_label')
        fill_in 'idv_form_zipcode', with: '12345'
        fill_in 'idv_form_address2', with: 'Apt 3E'

        click_button t('forms.buttons.submit.update')

        expect(page).to have_current_path(idv_verify_info_path)

        expect(page).to have_content('12345')
        expect(page).to have_content('Apt 3E')

        complete_verify_step

        expect(fake_analytics).to have_logged_event(
          'IdV: doc auth verify proofing results',
          hash_including(
            address_edited: true,
            address_line2_present: true,
            analytics_id: 'Doc Auth',
          ),
        )
      end

      it 'allows the user to enter in a new ssn and displays updated info' do
        click_link t('idv.buttons.change_ssn_label')

        expect(page).to have_current_path(idv_ssn_path)
        expect(page).to_not have_content(t('doc_auth.headings.capture_complete'))
        expect(
          find_field(t('idv.form.ssn_label')).value,
        ).to eq(DocAuthHelper::GOOD_SSN.gsub(/\D/, ''))

        fill_in t('idv.form.ssn_label'), with: '900456789'
        click_button t('forms.buttons.submit.update')

        expect(fake_analytics).to have_logged_event(
          'IdV: doc auth redo_ssn submitted',
        )

        expect(page).to have_current_path(idv_verify_info_path)

        expect(page).to have_text('9**-**-***9')
        check t('forms.ssn.show')
        expect(page).to have_text('900-45-6789')
      end

      it 'logs analytics event on submit' do
        complete_verify_step

        expect(fake_analytics).to have_logged_event(
          'IdV: doc auth verify proofing results',
          hash_including(address_edited: false, address_line2_present: false),
        )
      end
    end

    it 'does not proceed to the next page if resolution fails' do
      fill_out_ssn_form_with_ssn_that_fails_resolution
      click_idv_continue
      complete_verify_step

      expect(page).to have_current_path(idv_session_errors_warning_path)
      expect_step_indicator_current_step(t('step_indicator.flows.idv.verify_info'))
      click_on t('idv.failure.button.warning')

      expect(page).to have_current_path(idv_verify_info_path)
    end

    it 'does not proceed to the next page if resolution raises an exception' do
      fill_out_ssn_form_with_ssn_that_raises_exception

      click_idv_continue
      complete_verify_step

      expect(fake_analytics).to have_logged_event(
        'IdV: doc auth exception visited',
        step_name: 'verify_info',
        remaining_submit_attempts: 5,
      )
      expect(page).to have_current_path(idv_session_errors_exception_path)

      click_on t('idv.failure.button.warning')

      expect(page).to have_current_path(idv_verify_info_path)
    end

    context 'resolution rate limiting' do
      let(:max_resolution_attempts) { 3 }
      before do
        allow(IdentityConfig.store).to receive(:idv_max_attempts)
          .and_return(max_resolution_attempts)

        fill_out_ssn_form_with_ssn_that_fails_resolution
        click_idv_continue
      end

      # proof_ssn_max_attempts is 10, vs 5 for resolution, so it doesn't get triggered
      it 'rate limits resolution and continues when it expires' do
        expect(attempts_api_tracker).to receive(:idv_rate_limited).with(
          limiter_type: :idv_resolution,
        ).twice

        (max_resolution_attempts - 2).times do
          complete_verify_step
          expect(page).to have_current_path(idv_session_errors_warning_path)
          click_try_again
        end

        # Check that last attempt shows correct warning text
        complete_verify_step
        expect(page).to have_current_path(idv_session_errors_warning_path)
        expect(page).to have_content(
          strip_tags(
            t('idv.failure.attempts_html.one'),
          ),
        )
        click_try_again

        complete_verify_step
        expect(page).to have_current_path(idv_session_errors_failure_path)
        expect(page).not_to have_css('.step-indicator__step--current', text: text, wait: 5)
        expect(fake_analytics).to have_logged_event(
          'Rate Limit Reached',
          limiter_type: :idv_resolution,
          step_name: 'verify_info',
        )

        visit idv_verify_info_url
        expect(page).to have_current_path(idv_session_errors_failure_path)

        # Manual expiration is needed because Redis timestamp doesn't always match ruby timestamp
        RateLimiter.new(user: user, rate_limit_type: :idv_resolution).reset!
        travel_to(IdentityConfig.store.idv_attempt_window_in_hours.hours.from_now + 1) do
          sign_in_and_2fa_user(user)
          complete_doc_auth_steps_before_verify_step
          complete_verify_step

          expect(page).to have_current_path(idv_phone_path)
          expect(RateLimiter.new(user: user, rate_limit_type: :idv_resolution)).to_not be_limited
        end
      end

      it 'allows user to cancel identify verification' do
        click_link t('links.cancel')
        expect(page).to have_current_path(idv_cancel_path(step: 'verify'))
      end
    end

    context 'ssn rate limiting' do
      # Simulates someone trying same SSN with second account
      let(:max_resolution_attempts) { 4 }
      let(:max_ssn_attempts) { 3 }

      before do
        allow(IdentityConfig.store).to receive(:idv_max_attempts)
          .and_return(max_resolution_attempts)

        allow(IdentityConfig.store).to receive(:proof_ssn_max_attempts)
          .and_return(max_ssn_attempts)

        fill_out_ssn_form_with_ssn_that_fails_resolution
        click_idv_continue
        (max_ssn_attempts - 1).times do
          complete_verify_step
          expect(page).to have_current_path(idv_session_errors_warning_path)
          click_try_again
        end
      end

      it 'rate limits ssn and continues when it expires' do
        expect(attempts_api_tracker).to receive(:idv_rate_limited).with(
          limiter_type: :proof_ssn,
        ).twice

        complete_verify_step
        expect(page).to have_current_path(idv_session_errors_ssn_failure_path)
        expect(fake_analytics).to have_logged_event(
          'Rate Limit Reached',
          limiter_type: :proof_ssn,
          step_name: 'verify_info',
        )

        visit idv_verify_info_url
        # second rate limit event
        expect(page).to have_current_path(idv_session_errors_ssn_failure_path)

        # Manual expiration is needed because Redis timestamp doesn't always match ruby timestamp
        RateLimiter.new(user: user, rate_limit_type: :idv_resolution).reset!
        travel_to(IdentityConfig.store.idv_attempt_window_in_hours.hours.from_now + 1) do
          sign_in_and_2fa_user(user)
          complete_doc_auth_steps_before_verify_step
          complete_verify_step

          expect(page).to have_current_path(idv_phone_path)
          expect(RateLimiter.new(user: user, rate_limit_type: :idv_resolution)).to_not be_limited
        end
      end

      it 'continues to next step if ssn successful on last attempt' do
        click_link t('idv.buttons.change_ssn_label')

        expect(page).to have_current_path(idv_ssn_path)
        expect(page).to_not have_content(t('doc_auth.headings.capture_complete'))
        expect(
          find_field(t('idv.form.ssn_label')).value,
        ).not_to eq(DocAuthHelper::GOOD_SSN.gsub(/\D/, ''))

        fill_in t('idv.form.ssn_label'), with: '900456789'
        click_button t('forms.buttons.submit.update')
        complete_verify_step

        expect(page).to have_current_path(idv_phone_path)
        expect(fake_analytics).not_to have_logged_event(
          'Rate Limit Reached',
          limiter_type: :proof_ssn,
          step_name: 'verify_info',
        )
      end
    end

    context 'AAMVA' do
      let(:mock_state_id_jurisdiction) do
        [Idp::Constants::MOCK_IDV_APPLICANT_STATE_ID_JURISDICTION]
      end

      context 'when the user lives in an AAMVA supported state' do
        it 'performs a resolution and state ID check' do
          allow(IdentityConfig.store).to receive(:aamva_supported_jurisdictions).and_return(
            mock_state_id_jurisdiction,
          )
          expect_any_instance_of(Proofing::Mock::IdMockClient).to receive(:proof).with(
            hash_including(
              **Idp::Constants::MOCK_IDV_APPLICANT,
            ),
          ).and_call_original

          complete_ssn_step
          complete_verify_step
        end
      end

      context 'when the user does not live in an AAMVA supported state' do
        it 'does not perform the state ID check' do
          allow(IdentityConfig.store).to receive(:aamva_supported_jurisdictions).and_return(
            IdentityConfig.store.aamva_supported_jurisdictions -
            mock_state_id_jurisdiction,
          )
          expect_any_instance_of(Proofing::Mock::IdMockClient).to_not receive(:proof)

          complete_ssn_step
          complete_verify_step
        end
      end
    end

    context 'when phone pre-check is enabled' do
      let(:phonerisk_risk_score) { 0 }
      let(:phonerisk_correlation_score) { 1.0 }
      let(:phonerisk_respone) do
        {
          status: 200,
          body: {
            referenceId: 'some-reference-id',
            namePhoneCorrelation: {
              reasonCodes: [],
              score: phonerisk_correlation_score,
            },
            phoneRisk: {
              reasonCodes: [],
              score: phonerisk_risk_score,
            },
            customerProfile: {
              customerUserId: user.uuid,
            },
          }.to_json,
          headers: {
            'Content-Type': 'application/json',
          },
        }
      end

      before do
        allow(IdentityConfig.store).to receive(:idv_phone_precheck_enabled).and_return(true)
      end

      context 'when user does not have a phone number for pre-check' do
        let(:user) do
          create(:user, :with_backup_code)
        end

        it 'redirects user to the phone step' do
          complete_ssn_step
          complete_verify_step
          expect(page).to have_current_path(idv_phone_path)
        end
      end

      context 'when user fails phone pre-check' do
        let(:user) do
          create(:user, :fully_registered, with: { phone: '703-555-5555' })
        end

        it 'redirects user to the phone step' do
          expect_any_instance_of(Proofing::Socure::IdPlus::Proofers::PhoneRiskProofer)
            .not_to receive(:proof).and_call_original
          complete_ssn_step
          complete_verify_step
          expect(page).to have_current_path(idv_phone_path)

          prefilled_phone = page.find(id: 'idv_phone_form_phone').value
          expect(prefilled_phone).to eq('')
        end

        context 'when secondary vendor is enabled' do
          let(:phonerisk_risk_score) { 1.0 }
          let(:phonerisk_correlation_score) { 0 }
          before do
            allow(IdentityConfig.store).to receive(:idv_address_secondary_vendor)
              .and_return(:socure)

            stub_request(:post, 'https://sandbox.socure.test/api/3.0/EmailAuthScore')
              .to_return(phonerisk_respone)
          end
          it 'redirects user to the phone step' do
            expect_any_instance_of(Proofing::Socure::IdPlus::Proofers::PhoneRiskProofer)
              .to receive(:proof).and_call_original
            complete_ssn_step
            complete_verify_step
            expect(page).to have_current_path(idv_phone_path)

            prefilled_phone = page.find(id: 'idv_phone_form_phone').value
            expect(prefilled_phone).to eq('')
          end
        end
      end

      context 'when phone pre-check is successful' do
        it 'redirects the user to enter password page' do
          expect_any_instance_of(Proofing::Socure::IdPlus::Proofers::PhoneRiskProofer)
            .not_to receive(:proof).and_call_original
          complete_ssn_step
          complete_verify_step
          expect(page).to have_current_path(idv_enter_password_path)
        end

        context 'when secondary vendor is enabled' do
          let(:user) do
            create(:user, :fully_registered, with: { phone: '703-555-5555' })
          end

          before do
            allow(IdentityConfig.store).to receive(:idv_address_secondary_vendor)
              .and_return(:socure)

            stub_request(:post, 'https://sandbox.socure.test/api/3.0/EmailAuthScore')
              .to_return(phonerisk_respone)
          end

          it 'redirects the user to enter password page' do
            expect_any_instance_of(Proofing::Socure::IdPlus::Proofers::PhoneRiskProofer)
              .to receive(:proof).and_call_original
            complete_ssn_step
            complete_verify_step
            expect(page).to have_current_path(idv_enter_password_path)
          end
        end
      end

      context 'hybrid mobile flow' do
        before do
          allow(Telephony).to receive(:send_doc_auth_link).and_wrap_original do |impl, config|
            @sms_link = config[:link]
            impl.call(**config)
          end.at_least(1).times
        end

        context 'when precheck fail' do
          context 'with hybrid handoff number' do
            it 'it redirects to phone page' do
              perform_in_browser(:desktop) do
                sign_in_and_2fa_user(user)
                complete_doc_auth_steps_before_hybrid_handoff_step
                clear_and_fill_in(:doc_auth_phone, '703-555-5555') # '+1 415-555-0199')
                click_send_link
                expect(page).to have_current_path(idv_link_sent_path)
              end

              expect(@sms_link).to be_present

              perform_in_browser(:mobile) do
                visit @sms_link
                expect(page).to have_current_path(idv_hybrid_mobile_choose_id_type_url)
                complete_choose_id_type_step
                expect(page).to have_current_path(idv_hybrid_mobile_document_capture_url)

                attach_and_submit_images
                expect(page).to have_current_path(idv_hybrid_mobile_capture_complete_url)
              end

              perform_in_browser(:desktop) do
                click_idv_continue
                expect(page).to_not have_content(t('doc_auth.headings.text_message'), wait: 10)
                expect(page).to have_current_path(idv_ssn_path)

                fill_out_ssn_form_ok
                click_idv_continue

                expect(page).to have_content(t('headings.verify'))
                complete_verify_step

                expect(page).to have_current_path(idv_phone_path)
                prefilled_phone = page.find(id: 'idv_phone_form_phone').value

                # prefills with mfa phone
                expect(
                  PhoneFormatter.format(prefilled_phone),
                ).to eq(
                  PhoneFormatter.format(user.default_phone_configuration.phone), # +1 202-555-1212"
                )
              end
            end
          end

          context 'with mfa number' do
            let(:user) do
              create(:user, :fully_registered, with: { phone: '703-555-5555' })
            end
            it 'it redirects to phone page' do
              perform_in_browser(:desktop) do
                sign_in_and_2fa_user(user)
                complete_doc_auth_steps_before_hybrid_handoff_step
                click_send_link
                expect(page).to have_current_path(idv_link_sent_path)
              end

              expect(@sms_link).to be_present

              perform_in_browser(:mobile) do
                visit @sms_link
                expect(page).to have_current_path(idv_hybrid_mobile_choose_id_type_url)
                complete_choose_id_type_step
                expect(page).to have_current_path(idv_hybrid_mobile_document_capture_url)

                attach_and_submit_images
                expect(page).to have_current_path(idv_hybrid_mobile_capture_complete_url)
              end

              perform_in_browser(:desktop) do
                click_idv_continue
                expect(page).to_not have_content(t('doc_auth.headings.text_message'), wait: 10)
                expect(page).to have_current_path(idv_ssn_path)

                fill_out_ssn_form_ok
                click_idv_continue

                expect(page).to have_content(t('headings.verify'))
                complete_verify_step

                expect(page).to have_current_path(idv_phone_path)
                prefilled_phone = page.find(id: 'idv_phone_form_phone').value

                expect(prefilled_phone).to eq('')
              end
            end
          end
        end

        context 'when precheck is successful' do
          it 'it redirects to enter password page' do
            perform_in_browser(:desktop) do
              sign_in_and_2fa_user(user)
              complete_doc_auth_steps_before_hybrid_handoff_step
              clear_and_fill_in(:doc_auth_phone, '+1 415-555-0199')
              click_send_link
              expect(page).to have_current_path(idv_link_sent_path)
            end

            expect(@sms_link).to be_present

            perform_in_browser(:mobile) do
              visit @sms_link
              expect(page).to have_current_path(idv_hybrid_mobile_choose_id_type_url)
              complete_choose_id_type_step
              expect(page).to have_current_path(idv_hybrid_mobile_document_capture_url)

              attach_and_submit_images
              expect(page).to have_current_path(idv_hybrid_mobile_capture_complete_url)
            end

            perform_in_browser(:desktop) do
              click_idv_continue
              expect(page).to_not have_content(t('doc_auth.headings.text_message'), wait: 10)
              expect(page).to have_current_path(idv_ssn_path)

              fill_out_ssn_form_ok
              click_idv_continue

              expect(page).to have_content(t('headings.verify'))
              complete_verify_step

              expect(page).to have_current_path(idv_enter_password_path)
            end
          end
        end
      end
    end

    context 'async missing' do
      it 'allows resubmitting form' do
        complete_ssn_step

        allow(DocumentCaptureSession).to receive(:find_by)
          .and_return(nil)

        complete_verify_step
        expect(fake_analytics).to have_logged_event('IdV: proofing resolution result missing')
        expect(page).to have_content(t('idv.failure.timeout'))
        expect(page).to have_current_path(idv_verify_info_path)
        allow(DocumentCaptureSession).to receive(:find_by).and_call_original
        complete_verify_step
        expect(page).to have_current_path(idv_phone_path)
      end
    end

    context 'async timed out' do
      it 'allows resubmitting form' do
        complete_ssn_step

        allow(DocumentCaptureSession).to receive(:find_by)
          .and_return(nil)

        complete_verify_step
        expect(page).to have_content(t('idv.failure.timeout'))
        expect(page).to have_current_path(idv_verify_info_path)
        allow(DocumentCaptureSession).to receive(:find_by).and_call_original
        complete_verify_step
        expect(page).to have_current_path(idv_phone_path)
      end
    end
  end

  context 'phone vendor outage' do
    before do
      allow_any_instance_of(OutageStatus).to receive(:any_phone_vendor_outage?).and_return(true)
      visit_idp_from_sp_with_ial2(:oidc)
      sign_in_and_2fa_user(user)
      complete_doc_auth_steps_before_welcome_step
      click_idv_continue # Acknowledge mail-only alert
      complete_welcome_step
      complete_agreement_step
      complete_hybrid_handoff_step
      complete_choose_id_type_step
      complete_document_capture_step
      complete_ssn_step
    end

    it 'redirects to the gpo page when continuing from verify info page' do
      expect(page).to have_current_path(idv_verify_info_path)
      complete_verify_step
      expect(page).to have_current_path(idv_request_letter_path)

      click_on 'Cancel'
      expect(page).to have_current_path(idv_cancel_path(step: :gpo))
    end
  end
end
