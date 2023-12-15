require 'rails_helper'

RSpec.feature 'document capture step', :js do
  include IdvStepHelper
  include DocAuthHelper
  include DocCaptureHelper
  include ActionView::Helpers::DateHelper

  let(:max_attempts) { IdentityConfig.store.doc_auth_max_attempts }
  let(:user) { user_with_2fa }
  let(:fake_analytics) { FakeAnalytics.new }
  let(:sp_name) { 'Test SP' }
  let(:enable_not_ready) { true }
  let(:enable_exit_question) { true }
  before do
    allow_any_instance_of(ApplicationController).to receive(:analytics).and_return(fake_analytics)
    allow_any_instance_of(ServiceProviderSession).to receive(:sp_name).and_return(sp_name)
    allow(IdentityConfig.store).to receive(:doc_auth_not_ready_section_enabled).
      and_return(enable_not_ready)
    allow(IdentityConfig.store).to receive(:doc_auth_exit_question_section_enabled).
      and_return(enable_exit_question)
    visit_idp_from_oidc_sp_with_ial2

    sign_in_and_2fa_user(user)
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

    context 'rate limits calls to acuant', allow_browser_log: true do
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
        expect(fake_analytics).to have_logged_event(
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

      expect(DocAuthLog.find_by(user_id: user.id).state).to be_nil
    end

    it 'return to sp when click on exit link', :js do
      click_sp_exit_link(sp_name: sp_name)
      expect(current_url).to start_with('http://localhost:7654/auth/result?error=access_denied')
    end

    it 'logs event and return to sp when click on submit and exit button', :js do
      click_submit_exit_button
      expect(fake_analytics).to have_logged_event(
        'Frontend: IdV: exit optional questions',
        hash_including(:ids),
      )
      expect(current_url).to start_with('http://localhost:7654/auth/result?error=access_denied')
    end

    context 'not ready section' do
      it 'renders not ready section when enabled' do
        expect(page).to have_content(
          I18n.t(
            'doc_auth.not_ready.content_sp', sp_name: sp_name,
                                             app_name: APP_NAME
          ),
        )
      end
    end
  end

  context 'standard mobile flow' do
    it 'proceeds to the next page with valid info' do
      perform_in_browser(:mobile) do
        visit_idp_from_oidc_sp_with_ial2
        sign_in_and_2fa_user(user)
        complete_doc_auth_steps_before_document_capture_step

        expect(page).to have_current_path(idv_document_capture_url)
        expect_step_indicator_current_step(t('step_indicator.flows.idv.verify_id'))

        attach_and_submit_images

        expect(page).to have_current_path(idv_ssn_url)
        expect_costing_for_document
        expect(DocAuthLog.find_by(user_id: user.id).state).to eq('MT')

        expect(page).to have_current_path(idv_ssn_url)
        fill_out_ssn_form_ok
        click_idv_continue
        complete_verify_step
        expect(page).to have_current_path(idv_phone_url)
      end
    end
  end

  context 'with doc_auth_selfie_capture_enabled set to true' do
    before do
      allow(IdentityConfig.store).to receive(:doc_auth_selfie_capture_enabled).and_return(true)
    end

    it 'proceeds to the next page with valid info, including a selfie image' do
      perform_in_browser(:mobile) do
        visit_idp_from_oidc_sp_with_ial2
        sign_in_and_2fa_user(user)
        complete_doc_auth_steps_before_document_capture_step

        expect(page).to have_current_path(idv_document_capture_url)
        expect(page).not_to have_content(t('doc_auth.headings.document_capture_selfie'))

        visit(idv_document_capture_path(selfie: true))
        expect(page).to have_current_path(idv_document_capture_url(selfie: true))
        expect_step_indicator_current_step(t('step_indicator.flows.idv.verify_id'))
        expect_doc_capture_page_header(t('doc_auth.headings.document_capture_with_selfie'))
        expect_doc_capture_id_subheader
        expect_doc_capture_selfie_subheader
        attach_images
        attach_selfie
        submit_images

        expect(page).to have_current_path(idv_ssn_url)
        expect_costing_for_document
        expect(DocAuthLog.find_by(user_id: user.id).state).to eq('MT')

        expect(page).to have_current_path(idv_ssn_url)
        fill_out_ssn_form_ok
        click_idv_continue
        complete_verify_step
        expect(page).to have_current_path(idv_phone_url)
      end
    end

    context 'when hosted env is prod' do
      before do
        allow(Identity::Hostdata).to receive(:env).and_return('prod')
      end
      it 'proceeds to the next page with valid info, including a selfie image' do
        perform_in_browser(:mobile) do
          visit_idp_from_oidc_sp_with_ial2
          sign_in_and_2fa_user(user)
          complete_doc_auth_steps_before_document_capture_step

          expect(page).to have_current_path(idv_document_capture_url)
          expect(page).not_to have_content(t('doc_auth.headings.document_capture_selfie'))

          visit(idv_document_capture_path(selfie: true))
          expect(page).to have_current_path(idv_document_capture_url(selfie: true))
          expect_step_indicator_current_step(t('step_indicator.flows.idv.verify_id'))

          expect(page).not_to have_content(t('doc_auth.headings.document_capture_selfie'))
          attach_images
          submit_images

          expect(page).to have_current_path(idv_ssn_url)
          expect_costing_for_document
          expect(DocAuthLog.find_by(user_id: user.id).state).to eq('MT')

          expect(page).to have_current_path(idv_ssn_url)
          fill_out_ssn_form_ok
          click_idv_continue
          complete_verify_step
          expect(page).to have_current_path(idv_phone_url)
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
