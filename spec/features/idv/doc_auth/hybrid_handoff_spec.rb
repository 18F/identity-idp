require 'rails_helper'

RSpec.feature 'hybrid_handoff step send link and errors', allowed_extra_analytics: [:*] do
  include IdvStepHelper
  include DocAuthHelper
  include ActionView::Helpers::DateHelper

  let(:fake_analytics) { FakeAnalytics.new }
  let(:fake_attempts_tracker) { IrsAttemptsApiTrackingHelper::FakeAttemptsTracker.new }
  let(:idv_send_link_max_attempts) { 3 }
  let(:idv_send_link_attempt_window_in_minutes) do
    IdentityConfig.store.idv_send_link_attempt_window_in_minutes
  end

  context 'on a desktop device send link' do
    before do
      sign_in_and_2fa_user
      allow_any_instance_of(ApplicationController).to receive(:analytics).and_return(fake_analytics)
      allow_any_instance_of(ApplicationController).to receive(:irs_attempts_api_tracker).
        and_return(fake_attempts_tracker)
      complete_doc_auth_steps_before_hybrid_handoff_step
    end

    it 'has the forms with the expected aria attributes' do
      mobile_form = find('#form-to-submit-photos-through-mobile')
      desktop_form = find('#form-to-submit-photos-through-desktop')

      expect(mobile_form).to have_name(t('forms.buttons.send_link'))
      expect(desktop_form).to have_name(t('forms.buttons.upload_photos'))
    end

    it 'proceeds to link sent page when user chooses to use phone' do
      expect(fake_attempts_tracker).to receive(
        :idv_document_upload_method_selected,
      ).with({ upload_method: 'mobile' })

      click_send_link

      expect(page).to have_current_path(idv_link_sent_path)
      expect(fake_analytics).to have_logged_event(
        'IdV: doc auth hybrid handoff submitted',
        hash_including(step: 'hybrid_handoff', destination: :link_sent),
      )
    end

    it 'proceeds to the next page with valid info', :js do
      expect(fake_attempts_tracker).to receive(
        :idv_phone_upload_link_sent,
      ).with(
        success: true,
        phone_number: '+1 415-555-0199',
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
            I18n.t('errors.doc_auth.send_link_limited', timeout: timeout),
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
            'errors.doc_auth.send_link_limited',
            timeout: timeout,
          ),
        )
        expect(page).to have_selector('h1', text: t('doc_auth.headings.hybrid_handoff'))
        expect(page).to have_selector('h2', text: t('doc_auth.headings.upload_from_phone'))
      end
      expect(fake_analytics).to have_logged_event(
        'Rate Limit Reached',
        limiter_type: :idv_send_link,
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
      expect(Telephony).to receive(:send_doc_auth_link).and_wrap_original do |impl, config|
        params = Rack::Utils.parse_nested_query URI(config[:link]).query

        expect(params['document-capture-session']).to be_a_kind_of(String)

        impl.call(**config)
      end

      fill_in :doc_auth_phone, with: '415-555-0199'
      click_send_link
    end

    it 'sets requested_at on the capture session' do
      document_capture_session_uuid = nil

      expect(Telephony).to receive(:send_doc_auth_link).and_wrap_original do |impl, config|
        params = Rack::Utils.parse_nested_query URI(config[:link]).query
        document_capture_session_uuid = params['document-capture-session']
        impl.call(**config)
      end

      fill_in :doc_auth_phone, with: '415-555-0199'
      click_send_link

      document_capture_session = DocumentCaptureSession.find_by(uuid: document_capture_session_uuid)
      expect(document_capture_session).to be
      expect(document_capture_session).to have_attributes(requested_at: a_kind_of(Time))
    end
  end

  context 'on a desktop device when selfie required', js: true do
    let(:user) { user_with_2fa }
    before do
      expect(FeatureManagement).to receive(:idv_allow_selfie_check?).at_least(:once).
        and_return(true)
      sign_in_and_2fa_user(user)
      visit_idp_from_sp_with_ial2(:oidc, biometric_comparison_required: true)
      allow_any_instance_of(ApplicationController).to receive(:analytics).and_return(fake_analytics)
      allow_any_instance_of(ApplicationController).to receive(:irs_attempts_api_tracker).
        and_return(fake_attempts_tracker)
      complete_doc_auth_steps_before_document_capture_step
    end
    it 'it prevents from proceeding to document capture' do
      expect(page).to have_current_path(idv_hybrid_handoff_path)
      click_on t('forms.buttons.upload_photos')
      expect(page).to have_current_path(idv_hybrid_handoff_path)
    end
  end
end
