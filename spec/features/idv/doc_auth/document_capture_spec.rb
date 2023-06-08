require 'rails_helper'

feature 'doc auth document capture step', :js do
  include IdvStepHelper
  include DocAuthHelper
  include ActionView::Helpers::DateHelper

  let(:max_attempts) { IdentityConfig.store.doc_auth_max_attempts }
  let(:user) { user_with_2fa }
  let(:fake_analytics) { FakeAnalytics.new }
  let(:sp_name) { 'Test SP' }
  before do
    allow_any_instance_of(ApplicationController).to receive(:analytics).and_return(fake_analytics)
    allow_any_instance_of(ServiceProviderSessionDecorator).to receive(:sp_name).and_return(sp_name)

    visit_idp_from_oidc_sp_with_ial2

    sign_in_and_2fa_user(user)
  end

  it 'does not skip ahead in standard desktop flow' do
    visit(idv_document_capture_url)
    expect(page).to have_current_path(idv_doc_auth_welcome_step)
    complete_welcome_step
    visit(idv_document_capture_url)
    expect(page).to have_current_path(idv_doc_auth_agreement_step)
    complete_agreement_step
    visit(idv_document_capture_url)
    expect(page).to have_current_path(idv_hybrid_handoff_path)
  end

  context 'standard desktop flow' do
    before do
      complete_doc_auth_steps_before_document_capture_step
    end

    it 'shows the new DocumentCapture page for desktop standard flow' do
      expect(page).to have_current_path(idv_document_capture_path)

      expect(page).to have_content(t('doc_auth.headings.document_capture').tr(' ', ' '))
      expect(page).to have_content(t('step_indicator.flows.idv.verify_id'))

      expect(fake_analytics).to have_logged_event(
        'IdV: doc auth document_capture visited',
        flow_path: 'standard',
        step: 'document_capture',
        analytics_id: 'Doc Auth',
        irs_reproofing: false,
        acuant_sdk_upgrade_ab_test_bucket: :default,
      )

      # it redirects here if trying to move earlier in the flow
      visit(idv_doc_auth_agreement_step)
      expect(page).to have_current_path(idv_document_capture_path)
      visit(idv_hybrid_handoff_url)
      expect(page).to have_current_path(idv_document_capture_path)
    end

    it 'logs return to sp link click' do
      new_window = window_opened_by do
        click_on t('idv.troubleshooting.options.get_help_at_sp', sp_name: sp_name)
      end

      within_window new_window do
        expect(fake_analytics).to have_logged_event(
          'Return to SP: Failed to proof',
          flow: nil,
          location: 'document_capture_troubleshooting_options',
          redirect_url: instance_of(String),
          step: 'document_capture',
        )
      end
    end

    context 'throttles calls to acuant', allow_browser_log: true do
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

      it 'redirects to the throttled error page' do
        freeze_time do
          attach_and_submit_images
          timeout = distance_of_time_in_words(
            Throttle.attempt_window_in_minutes(:idv_doc_auth).minutes,
          )
          message = strip_tags(t('errors.doc_auth.throttled_text_html', timeout: timeout))
          expect(page).to have_content(message)
          expect(page).to have_current_path(idv_session_errors_throttled_path)
        end
      end

      it 'logs the throttled analytics event for doc_auth' do
        attach_and_submit_images
        expect(fake_analytics).to have_logged_event(
          'Throttler Rate Limit Triggered',
          throttle_type: :idv_doc_auth,
        )
      end

      it 'logs irs attempts event for rate limiting' do
        attach_and_submit_images
        expect(fake_attempts_tracker).to have_received(:idv_document_upload_rate_limited)
      end
    end

    it 'proceeds to the next page with valid info' do
      expect_step_indicator_current_step(t('step_indicator.flows.idv.verify_id'))

      attach_and_submit_images

      expect(page).to have_current_path(idv_ssn_url)
      expect_costing_for_document
      expect(DocAuthLog.find_by(user_id: user.id).state).to eq('MT')

      visit(idv_document_capture_url)
      expect(page).to have_current_path(idv_ssn_url)
      fill_out_ssn_form_ok
      click_idv_continue
      complete_verify_step
      expect(page).to have_current_path(idv_phone_url)
      visit(idv_document_capture_url)
      expect(page).to have_current_path(idv_phone_url)
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

        visit(idv_document_capture_url)
        expect(page).to have_current_path(idv_ssn_url)
        fill_out_ssn_form_ok
        click_idv_continue
        complete_verify_step
        expect(page).to have_current_path(idv_phone_url)
        visit(idv_document_capture_url)
        expect(page).to have_current_path(idv_phone_url)
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
