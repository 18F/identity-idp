require 'rails_helper'

RSpec.feature 'hybrid_handoff step send link and errors' do
  include IdvStepHelper
  include DocAuthHelper
  include ActionView::Helpers::DateHelper

  let(:fake_analytics) { FakeAnalytics.new }
  let(:fake_attempts_tracker) { IrsAttemptsApiTrackingHelper::FakeAttemptsTracker.new }
  let(:document_capture_session) { DocumentCaptureSession.create! }
  let(:idv_send_link_max_attempts) { 3 }
  let(:idv_send_link_attempt_window_in_minutes) do
    IdentityConfig.store.idv_send_link_attempt_window_in_minutes
  end

  before do
    sign_in_and_2fa_user
    allow_any_instance_of(Idv::HybridHandoffController).to receive(:mobile_device?).and_return(true)
    allow_any_instance_of(ApplicationController).to receive(:analytics).and_return(fake_analytics)
    allow_any_instance_of(ApplicationController).to receive(:irs_attempts_api_tracker).
      and_return(fake_attempts_tracker)
  end

  context 'on a desktop device send link' do
    before do
      complete_doc_auth_steps_before_hybrid_handoff_step
      allow_any_instance_of(
        Idv::HybridHandoffController,
      ).to receive(
        :mobile_device?,
      ).and_return(false)
    end

    it 'proceeds to link sent page when user chooses to use phone' do
      expect(fake_attempts_tracker).to receive(
        :idv_document_upload_method_selected,
      ).with({ upload_method: 'mobile' })

      click_send_link

      expect(page).to have_current_path(idv_link_sent_path)
      expect(fake_analytics).to have_logged_event(
        'IdV: doc auth upload submitted',
        hash_including(step: 'upload', destination: :link_sent),
      )

      visit(idv_hybrid_handoff_url)
      expect(page).to have_current_path(idv_link_sent_path)
    end

    it 'proceeds to the next page with valid info', :js do
      expect(fake_attempts_tracker).to receive(
        :idv_phone_upload_link_sent,
      ).with(
        success: true,
        phone_number: '+1 415-555-0199',
        failure_reason: nil,
      )

      expect(Telephony).to receive(:send_doc_auth_link).
        with(hash_including(to: '+1 415-555-0199')).
        and_call_original

      expect_step_indicator_current_step(t('step_indicator.flows.idv.verify_id'))

      fill_in :doc_auth_phone, with: '415-555-0199'
      click_send_link

      expect(page).to have_current_path(idv_link_sent_path)
    end

    it 'does not proceed to the next page with invalid info', :js do
      fill_in :doc_auth_phone, with: ''
      click_send_link

      expect(page).to have_current_path(idv_hybrid_handoff_path, ignore_query: true)
    end

    it 'sends a link that does not contain any underscores' do
      # because URLs with underscores sometimes get messed up by carriers
      expect(Telephony).to receive(:send_doc_auth_link).and_wrap_original do |impl, config|
        expect(config[:link]).to_not include('_')

        impl.call(**config)
      end

      fill_in :doc_auth_phone, with: '415-555-0199'
      click_send_link

      expect(page).to have_current_path(idv_link_sent_path)
    end

    it 'does not proceed if Telephony raises an error' do
      expect(fake_attempts_tracker).to receive(:idv_phone_upload_link_sent).with(
        success: false,
        phone_number: '+1 225-555-1000',
        failure_reason: { telephony: ['TelephonyError'] },
      )
      fill_in :doc_auth_phone, with: '225-555-1000'

      click_send_link

      expect(page).to have_current_path(idv_hybrid_handoff_path, ignore_query: true)
      expect(page).to have_content I18n.t('telephony.error.friendly_message.generic')
    end

    it 'displays error if user selects a country to which we cannot send SMS', js: true do
      page.find('div[aria-label="Country code"]').click
      within(page.find('.iti__flag-container', visible: :all)) do
        find('span', text: 'Sri Lanka').click
      end
      focused_input = page.find('.phone-input__number:focus')

      error_message_id = focused_input[:'aria-describedby']&.split(' ')&.find do |id|
        page.has_css?(".usa-error-message##{id}")
      end
      expect(error_message_id).to_not be_empty

      error_message = page.find_by_id(error_message_id)
      expect(error_message).to have_content(
        t(
          'two_factor_authentication.otp_delivery_preference.sms_unsupported',
          location: 'Sri Lanka',
        ),
      )
      click_send_link
      expect(page.find(':focus')).to match_css('.phone-input__number')
    end

    it 'rate limits sending the link' do
      user = user_with_2fa
      sign_in_and_2fa_user(user)
      complete_doc_auth_steps_before_hybrid_handoff_step
      timeout = distance_of_time_in_words(
        RateLimiter.attempt_window_in_minutes(:idv_send_link).minutes,
      )
      allow(IdentityConfig.store).to receive(:idv_send_link_max_attempts).
        and_return(idv_send_link_max_attempts)

      expect(fake_attempts_tracker).to receive(
        :idv_phone_send_link_rate_limited,
      ).with({ phone_number: '+1 415-555-0199' })

      freeze_time do
        idv_send_link_max_attempts.times do
          expect(page).to_not have_content(
            I18n.t('errors.doc_auth.send_link_throttle', timeout: timeout),
          )

          fill_in :doc_auth_phone, with: '415-555-0199'
          click_send_link

          expect(page).to have_current_path(idv_link_sent_path)

          click_doc_auth_back_link
        end

        fill_in :doc_auth_phone, with: '415-555-0199'

        click_send_link
        expect(page).to have_current_path(idv_hybrid_handoff_path, ignore_query: true)
        expect(page).to have_content(
          I18n.t(
            'errors.doc_auth.send_link_throttle',
            timeout: timeout,
          ),
        )
      end
      expect(fake_analytics).to have_logged_event(
        'Throttler Rate Limit Triggered',
        throttle_type: :idv_send_link,
      )

      # Manual expiration is needed for now since the RateLimiter uses
      # Redis ttl instead of expiretime
      RateLimiter.new(rate_limit_type: :idv_send_link, user: user).reset!
      travel_to(Time.zone.now + idv_send_link_attempt_window_in_minutes.minutes) do
        fill_in :doc_auth_phone, with: '415-555-0199'
        click_send_link
        expect(page).to have_current_path(idv_link_sent_path)
      end
    end

    it 'includes expected URL parameters' do
      allow_any_instance_of(
        Idv::HybridHandoffController,
      ).to receive(
        :flow_session,
      ).and_wrap_original do |method, args|
        session = method.call(*args)
        session['document_capture_session_uuid'] = document_capture_session.uuid
        session
      end

      expect(Telephony).to receive(:send_doc_auth_link).and_wrap_original do |impl, config|
        params = Rack::Utils.parse_nested_query URI(config[:link]).query
        expect(params).to eq('document-capture-session' => document_capture_session.uuid)

        impl.call(**config)
      end

      fill_in :doc_auth_phone, with: '415-555-0199'
      click_send_link
    end

    it 'sets requested_at on the capture session' do
      allow_any_instance_of(
        Idv::HybridHandoffController,
      ).to receive(
        :flow_session,
      ).and_wrap_original do |method, args|
        session = method.call(*args)
        session['document_capture_session_uuid'] = document_capture_session.uuid
        session
      end

      fill_in :doc_auth_phone, with: '415-555-0199'
      click_send_link

      document_capture_session.reload
      expect(document_capture_session).to have_attributes(requested_at: a_kind_of(Time))
    end
  end
end
