require 'rails_helper'

feature 'doc auth send link step' do
  include IdvStepHelper
  include DocAuthHelper
  include ActionView::Helpers::DateHelper

  before do
    sign_in_and_2fa_user
    complete_doc_auth_steps_before_send_link_step
  end

  let(:idv_send_link_max_attempts) { IdentityConfig.store.idv_send_link_max_attempts }
  let(:idv_send_link_attempt_window_in_minutes) do
    IdentityConfig.store.idv_send_link_attempt_window_in_minutes
  end
  let(:document_capture_session) { DocumentCaptureSession.create! }
  let(:fake_analytics) { FakeAnalytics.new }

  it 'is on the correct page' do
    expect(page).to have_current_path(idv_doc_auth_send_link_step)
    expect(page).to have_content(t('doc_auth.headings.take_picture'))
    expect(page).to have_css(
      '.step-indicator__step--current',
      text: t('step_indicator.flows.idv.verify_id'),
    )
  end

  it 'proceeds to the next page with valid info' do
    expect(Telephony).to receive(:send_doc_auth_link).
      with(hash_including(to: '+1 415-555-0199')).
      and_call_original

    fill_in :doc_auth_phone, with: '415-555-0199'
    click_idv_continue

    expect(page).to have_current_path(idv_doc_auth_link_sent_step)
  end

  it 'sends a link that does not contain any underscores' do
    # because URLs with underscores sometimes get messed up by carriers
    expect(Telephony).to receive(:send_doc_auth_link).and_wrap_original do |impl, config|
      expect(config[:link]).to_not include('_')

      impl.call(**config)
    end

    fill_in :doc_auth_phone, with: '415-555-0199'
    click_idv_continue

    expect(page).to have_current_path(idv_doc_auth_link_sent_step)
  end

  it 'does not proceed to the next page with invalid info' do
    fill_in :doc_auth_phone, with: ''
    click_idv_continue

    expect(page).to have_current_path(idv_doc_auth_send_link_step)
  end

  it 'does not proceed if Telephony raises an error' do
    fill_in :doc_auth_phone, with: '225-555-1000'
    click_idv_continue

    expect(page).to have_current_path(idv_doc_auth_send_link_step)
    expect(page).to have_content I18n.t('telephony.error.friendly_message.generic')
  end

  it 'displays error if user selects a country to which we cannot send SMS', js: true do
    page.find('div[aria-label="Country code"]').click
    within(page.find('.iti__flag-container', visible: :all)) do
      find('span', text: 'Sri Lanka').click
    end
    focused_input = page.find('.phone-input__number:focus')
    error_message = page.find_by_id(focused_input[:'aria-describedby'])
    expect(error_message).to have_content(
      t(
        'two_factor_authentication.otp_delivery_preference.sms_unsupported',
        location: 'Sri Lanka',
      ),
    )
    click_continue
    expect(page.find(':focus')).to match_css('.phone-input__number')
  end

  it 'throttles sending the link' do
    allow_any_instance_of(ApplicationController).to receive(:analytics).and_return(fake_analytics)
    user = user_with_2fa
    sign_in_and_2fa_user(user)
    complete_doc_auth_steps_before_send_link_step
    timeout = distance_of_time_in_words(
      Throttle.attempt_window_in_minutes(:idv_send_link).minutes,
    )
    freeze_time do
      idv_send_link_max_attempts.times do
        expect(page).to_not have_content(
          I18n.t('errors.doc_auth.send_link_throttle', timeout: timeout),
        )

        fill_in :doc_auth_phone, with: '415-555-0199'
        click_idv_continue

        expect(page).to have_current_path(idv_doc_auth_link_sent_step)
        click_doc_auth_back_link
      end

      fill_in :doc_auth_phone, with: '415-555-0199'
      click_idv_continue
      expect(page).to have_current_path(idv_doc_auth_send_link_step)
      expect(page).to have_content(I18n.t('errors.doc_auth.send_link_throttle', timeout: timeout))
    end
    expect(fake_analytics).to have_logged_event(
      Analytics::THROTTLER_RATE_LIMIT_TRIGGERED,
      throttle_type: :idv_send_link,
    )

    # Manual expiration is needed for now since the Throttle uses Redis ttl instead of expiretime
    Throttle.new(throttle_type: :idv_send_link, user: user).reset!
    travel_to(Time.zone.now + idv_send_link_attempt_window_in_minutes.minutes) do
      fill_in :doc_auth_phone, with: '415-555-0199'
      click_idv_continue
      expect(page).to have_current_path(idv_doc_auth_link_sent_step)
    end
  end

  it 'includes expected URL parameters' do
    allow_any_instance_of(Flow::BaseFlow).to receive(:flow_session).and_return(
      document_capture_session_uuid: document_capture_session.uuid,
    )

    expect(Telephony).to receive(:send_doc_auth_link).and_wrap_original do |impl, config|
      params = Rack::Utils.parse_nested_query URI(config[:link]).query
      expect(params).to eq('document-capture-session' => document_capture_session.uuid)

      impl.call(**config)
    end

    fill_in :doc_auth_phone, with: '415-555-0199'
    click_idv_continue
  end

  it 'sets requested_at on the capture session' do
    allow_any_instance_of(Flow::BaseFlow).to receive(:flow_session).and_return(
      document_capture_session_uuid: document_capture_session.uuid,
    )

    fill_in :doc_auth_phone, with: '415-555-0199'
    click_idv_continue

    document_capture_session.reload
    expect(document_capture_session).to have_attributes(requested_at: a_kind_of(Time))
  end
end
