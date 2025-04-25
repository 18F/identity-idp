require 'rails_helper'

RSpec.feature 'hybrid_handoff step send link and errors', :js do
  include IdvStepHelper
  include DocAuthHelper
  include ActionView::Helpers::DateHelper
  include PassportApiHelpers

  let(:fake_analytics) { FakeAnalytics.new }
  let(:idv_send_link_max_attempts) { 3 }
  let(:idv_send_link_attempt_window_in_minutes) do
    IdentityConfig.store.idv_send_link_attempt_window_in_minutes
  end
  let(:facial_match_required) { false }
  let(:passports_enabled) { false }
  before do
    if facial_match_required
      visit_idp_from_oidc_sp_with_ial2(
        facial_match_required: facial_match_required,
      )
    end
    sign_in_and_2fa_user
    allow_any_instance_of(ApplicationController).to receive(:analytics).and_return(fake_analytics)

    stub_health_check_settings
    stub_health_check_endpoints

    allow(IdentityConfig.store).to receive(:doc_auth_passports_enabled).and_return(passports_enabled)
  end

  context 'on a desktop device send link' do
    before do
      complete_doc_auth_steps_before_hybrid_handoff_step
    end

    it 'has the forms with the expected aria attributes' do
      mobile_form = find('#form-to-submit-photos-through-mobile')
      desktop_form = find('#form-to-submit-photos-through-desktop')

      expect(mobile_form).to have_name(t('forms.buttons.send_link'))
      expect(desktop_form).to have_name(t('forms.buttons.upload_photos'))
    end

    it 'proceeds to link sent page when user chooses to use phone' do
      click_send_link

      expect(page).to have_current_path(idv_link_sent_path)
      expect(fake_analytics).to have_logged_event(
        'IdV: doc auth hybrid handoff submitted',
        hash_including(step: 'hybrid_handoff', destination: :link_sent),
      )
    end

    it 'proceeds to the next page with valid info', :js do
      expect(Telephony).to receive(:send_doc_auth_link)
        .with(hash_including(to: '+1 415-555-0199'))
        .and_call_original

      expect_step_indicator_current_step(t('step_indicator.flows.idv.verify_id'))

      fill_in :doc_auth_phone, with: '415-555-0199'
      click_send_link

      expect(page).to have_current_path(idv_link_sent_path)
    end

    it 'does not proceed to the next page with invalid info', :js do
      fill_in :doc_auth_phone, with: ''
      click_send_link

      expect(page).to have_current_path(idv_hybrid_handoff_path)
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
      fill_in :doc_auth_phone, with: '225-555-1000'

      click_send_link

      expect(page).to have_current_path(idv_hybrid_handoff_path)
      expect(page).to have_content I18n.t('telephony.error.friendly_message.generic')
    end

    it 'displays error if user selects a country to which we cannot send SMS', js: true do
      click_on t('components.phone_input.country_code_label')
      within(page.find('.iti__country-container', visible: :all)) do
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
      allow(IdentityConfig.store).to receive(:idv_send_link_max_attempts)
        .and_return(idv_send_link_max_attempts)

      freeze_time do
        idv_send_link_max_attempts.times do
          expect(page).to_not have_content(
            I18n.t('doc_auth.errors.send_link_limited', timeout: timeout),
          )

          fill_in :doc_auth_phone, with: '415-555-0199'
          click_send_link

          expect(page).to have_current_path(idv_link_sent_path)

          click_doc_auth_back_link
        end

        fill_in :doc_auth_phone, with: '415-555-0199'

        click_send_link
        expect(page).to have_current_path(idv_hybrid_handoff_path)
        expect(page).to have_content(
          I18n.t(
            'doc_auth.errors.send_link_limited',
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

      fill_in :doc_auth_phone, with: ''
      fill_in :doc_auth_phone, with: '415-555-0199'

      click_send_link
    end

    it 'sets requested_at on the capture session' do
      doc_capture_session_uuid = nil

      expect(Telephony).to receive(:send_doc_auth_link).and_wrap_original do |impl, config|
        params = Rack::Utils.parse_nested_query URI(config[:link]).query
        doc_capture_session_uuid = params['document-capture-session']
        impl.call(**config)
      end

      fill_in :doc_auth_phone, with: ''
      fill_in :doc_auth_phone, with: '415-555-0199'
      click_send_link

      expect(page).to have_content(t('doc_auth.headings.text_message'))

      document_capture_session = DocumentCaptureSession.find_by(uuid: doc_capture_session_uuid)
      expect(document_capture_session).to be
      expect(document_capture_session).to have_attributes(requested_at: a_kind_of(Time))
    end
  end

  context 'on a desktop device and selfie is allowed' do
    before do
      complete_doc_auth_steps_before_hybrid_handoff_step
    end

    describe 'when selfie is required by sp' do
      let(:facial_match_required) { true }
      it 'has expected UI elements' do
        mobile_form = find('#form-to-submit-photos-through-mobile')
        expect(mobile_form).to have_name(t('forms.buttons.send_link'))
        expect(page).to have_selector('h1', text: t('doc_auth.headings.hybrid_handoff_selfie'))
      end
      context 'on a desktop choose ipp', js: true do
        let(:in_person_doc_auth_button_enabled) { true }
        let(:sp_ipp_enabled) { true }
        before do
          allow(IdentityConfig.store).to receive(:in_person_doc_auth_button_enabled)
            .and_return(in_person_doc_auth_button_enabled)
          allow(Idv::InPersonConfig).to receive(:enabled_for_issuer?).with(anything)
            .and_return(sp_ipp_enabled)
          complete_doc_auth_steps_before_hybrid_handoff_step
        end

        context 'when ipp is enabled' do
          it 'proceeds to ipp if selected and can go back' do
            expect(page).to have_content(strip_tags(t('doc_auth.info.hybrid_handoff_ipp_html')))
            click_on t('in_person_proofing.headings.prepare')
            hybrid_step = { step: 'hybrid_handoff' }
            expect(page).to have_current_path(idv_document_capture_path(hybrid_step))
            click_on t('forms.buttons.back')
            expect(page).to have_current_path(idv_hybrid_handoff_path)
          end
        end

        context 'when ipp is disabled' do
          let(:in_person_doc_auth_button_enabled) { false }
          let(:sp_ipp_enabled) { false }
          it 'has no ipp option can be selected' do
            expect(page).to_not have_content(
              strip_tags(t('doc_auth.info.hybrid_handoff_ipp_html')),
            )
            expect(page).to_not have_content(
              t('in_person_proofing.headings.prepare'),
            )
          end
        end
      end
    end

    describe 'when selfie is not required by sp' do
      let(:facial_match_required) { false }
      it 'has expected UI elements' do
        mobile_form = find('#form-to-submit-photos-through-mobile')
        desktop_form = find('#form-to-submit-photos-through-desktop')

        expect(mobile_form).to have_name(t('forms.buttons.send_link'))
        expect(desktop_form).to have_name(t('forms.buttons.upload_photos'))
      end
    end
  end
end
RSpec.feature 'hybrid_handoff step for ipp, selfie variances', js: true do
  include IdvStepHelper
  include DocAuthHelper
  include InPersonHelper
  include PassportApiHelpers

  def verify_handoff_page_selfie_version_content(page)
    expect(page).to have_current_path(idv_hybrid_handoff_path)
    expect(page).to have_selector(
      'h1',
      text: t('doc_auth.headings.hybrid_handoff_selfie'),
    )
  end

  def verify_handoff_page_non_selfie_version_content(page)
    expect(page).to have_current_path(idv_hybrid_handoff_path)
    expect(page).to_not have_selector(
      'h1',
      text: t('doc_auth.headings.hybrid_handoff_selfie'),
    )
    expect(page).to have_selector(
      'h1',
      text: t('doc_auth.headings.hybrid_handoff'),
    )
  end

  def verify_handoff_page_no_ipp_option_shown(page)
    expect(page).to_not have_content(strip_tags(t('doc_auth.info.hybrid_handoff_ipp_html')))
    expect(page).to_not have_link(
      t('in_person_proofing.headings.prepare'),
      href: idv_document_capture_path(step: :hybrid_handoff),
    )
  end

  def verify_handoff_page_ipp_section_and_link(page)
    expect(page).to have_content(strip_tags(t('doc_auth.info.hybrid_handoff_ipp_html')))
    expect(page).to have_link(
      t('in_person_proofing.headings.prepare'),
      href: idv_document_capture_path(step: :hybrid_handoff),
    )
    click_on t('in_person_proofing.headings.prepare')
    expect(page).to have_current_path(idv_document_capture_path({ step: 'hybrid_handoff' }))
    expect_in_person_step_indicator_current_step(t('step_indicator.flows.idv.find_a_post_office'))
    expect(page).to have_content(t('headings.verify'))
    click_on t('forms.buttons.back')
    expect(page).to have_current_path(idv_hybrid_handoff_path)
  end

  def verify_upload_photos_section_and_link(page)
    expect(page).to have_content(t('doc_auth.headings.upload_from_computer'))
    click_on t('forms.buttons.upload_photos')
    expect(page).to have_current_path(idv_document_capture_url)
    expect_step_indicator_current_step(t('step_indicator.flows.idv.verify_id'))

    click_link t('links.cancel')
    expect(page).to have_content(t('idv.cancel.headings.prompt.standard'))
    expect(page).to have_current_path(idv_cancel_path, ignore_query: true)
  end

  def verify_no_upload_photos_section_and_link(page)
    expect(page).to_not have_content(t('doc_auth.headings.upload_from_computer'))
  end

  before do
    allow(IdentityConfig.store).to receive(:doc_auth_passports_enabled).and_return(passports_enabled)
    stub_health_check_settings
    stub_health_check_endpoints
  end

  let(:passports_enabled) { false }

  context 'on a desktop device with various ipp, socure, and selfie configuration' do
    let(:in_person_proofing_enabled) { true }
    let(:sp_ipp_enabled) { true }
    let(:in_person_proofing_opt_in_enabled) { true }
    let(:facial_match_required) { true }
    let(:socure_docv_enabled) { false }
    let(:doc_auth_vendor) { Idp::Constants::Vendors::MOCK }
    let(:desktop_test_mode_enabled) { false }
    let(:user) { user_with_2fa }

    before do
      service_provider = create(:service_provider, :active, :in_person_proofing_enabled)
      unless sp_ipp_enabled
        service_provider.in_person_proofing_enabled = false
        service_provider.save!
      end
      allow(IdentityConfig.store).to receive(:socure_docv_enabled).and_return(socure_docv_enabled)
      allow(IdentityConfig.store).to receive(:doc_auth_vendor_default).and_return(doc_auth_vendor)
      allow(IdentityConfig.store).to receive(:doc_auth_selfie_desktop_test_mode)
        .and_return(desktop_test_mode_enabled)
      allow(IdentityConfig.store).to receive(:in_person_proofing_enabled).and_return(
        in_person_proofing_enabled,
      )
      allow(IdentityConfig.store).to receive(:in_person_proofing_opt_in_enabled).and_return(
        in_person_proofing_opt_in_enabled,
      )
      allow_any_instance_of(ServiceProvider).to receive(:in_person_proofing_enabled)
        .and_return(sp_ipp_enabled)
      visit_idp_from_sp_with_ial2(
        :oidc,
        **{ client_id: service_provider.issuer,
            facial_match_required: facial_match_required },
      )
      sign_in_via_branded_page(user)
      complete_doc_auth_steps_before_agreement_step
      complete_agreement_step
    end

    context 'when socure is the doc auth vendor' do
      let(:facial_match_required) { false }
      let(:in_person_proofing_opt_in_enabled) { false }
      let(:sp_ipp_enabled) { false }
      let(:socure_docv_enabled) { true }
      let(:doc_auth_vendor) { Idp::Constants::Vendors::SOCURE }

      context 'when socure desktop test mode is not enabled' do
        it 'shows phone only top content no upload section' do
          verify_handoff_page_non_selfie_version_content(page)
          verify_no_upload_photos_section_and_link(page)
        end
      end

      context 'when socure desktop test mode is enabled' do
        let(:desktop_test_mode_enabled) { true }

        it 'shows phone top content and desktop upload content' do
          verify_handoff_page_non_selfie_version_content(page)
          expect(page).to have_content(t('doc_auth.headings.upload_from_computer'))
        end
      end
    end

    context 'when ipp is available system wide' do
      context 'when in person proofing opt in enabled' do
        context 'when sp ipp is available' do
          before do
            expect(page).to have_current_path(idv_how_to_verify_path)
          end
          describe 'when selfie is required by sp' do
            before do
              click_on t('forms.buttons.continue_online_mobile')
            end
            it 'shows selfie version of top content and ipp option section' do
              verify_handoff_page_selfie_version_content(page)
              verify_handoff_page_ipp_section_and_link(page)
              verify_no_upload_photos_section_and_link(page)
            end
          end
          describe 'when selfie is not required by sp' do
            let(:facial_match_required) { false }
            before do
              click_on t('forms.buttons.continue_online')
            end
            it 'shows non selfie version of top content and upload section,
                no ipp option section' do
              verify_handoff_page_non_selfie_version_content(page)
              verify_handoff_page_no_ipp_option_shown(page)
              verify_upload_photos_section_and_link(page)
            end
          end
        end
        context 'when sp ipp is not available' do
          let(:sp_ipp_enabled) { false }
          describe 'when selfie is required by sp' do
            let(:facial_match_required) { true }
            it 'shows selfie version of top content, no ipp option section,
                no upload section' do
              verify_handoff_page_selfie_version_content(page)
              verify_handoff_page_no_ipp_option_shown(page)
              verify_no_upload_photos_section_and_link(page)
            end
          end
          describe 'when selfie is not required by sp' do
            let(:facial_match_required) { false }
            it 'shows non selfie version of top content and upload section,
                no ipp option section' do
              verify_handoff_page_non_selfie_version_content(page)
              verify_handoff_page_no_ipp_option_shown(page)
              verify_upload_photos_section_and_link(page)
            end
          end
        end
      end

      context 'when in person proofing opt in disabled' do
        let(:in_person_proofing_opt_in_enabled) { false }
        context 'when sp ipp is not available' do
          let(:sp_ipp_enabled) { false }

          describe 'when selfie is required by sp' do
            let(:facial_match_required) { true }
            it 'shows selfie version of top content, no upload section,
                no ipp option section' do
              verify_handoff_page_selfie_version_content(page)
              verify_handoff_page_no_ipp_option_shown(page)
              verify_no_upload_photos_section_and_link(page)
            end
          end
          describe 'when selfie is not required by sp' do
            let(:facial_match_required) { false }
            it 'shows non selfie version of top content and upload section,
                no ipp option section' do
              verify_handoff_page_non_selfie_version_content(page)
              verify_handoff_page_no_ipp_option_shown(page)
              verify_upload_photos_section_and_link(page)
            end
          end
        end
        context 'when sp ipp is available' do
          let(:sp_ipp_enabled) { true }
          context 'when selfie is disabled system wide' do
            describe 'when selfie is not required by sp' do
              let(:facial_match_required) { false }
              it 'shows non selfie version of top content and upload section,
                  no ipp option section' do
                verify_handoff_page_non_selfie_version_content(page)
                verify_handoff_page_no_ipp_option_shown(page)
                verify_upload_photos_section_and_link(page)
              end
            end
          end
        end
      end
    end

    context 'when ipp is not available system wide' do
      let(:in_person_proofing_enabled) { false }
      context 'when ipp opt in is enabled' do
        let(:in_person_proofing_opt_in_enabled) { true }
        context 'when sp ipp is available' do
          let(:sp_ipp_enabled) { true }
          describe 'when selfie is required by sp' do
            let(:facial_match_required) { true }
            it 'shows selfie version of top content, no upload section,
                no ipp option section' do
              verify_handoff_page_selfie_version_content(page)
              verify_handoff_page_no_ipp_option_shown(page)
              verify_no_upload_photos_section_and_link(page)
            end
          end
          describe 'when selfie is not required by sp' do
            let(:facial_match_required) { false }
            it 'shows non selfie version of top content and upload section,
                no ipp option section' do
              verify_handoff_page_non_selfie_version_content(page)
              verify_handoff_page_no_ipp_option_shown(page)
              verify_upload_photos_section_and_link(page)
            end
          end
        end
        context 'when sp ipp is not available' do
          let(:sp_ipp_enabled) { false }
          describe 'when selfie is required by sp' do
            let(:facial_match_required) { true }
            it 'shows selfie version of top content, no upload section,
                no ipp option section' do
              verify_handoff_page_selfie_version_content(page)
              verify_handoff_page_no_ipp_option_shown(page)
              verify_no_upload_photos_section_and_link(page)
            end
          end
          describe 'when selfie is not required by sp' do
            let(:facial_match_required) { false }
            it 'shows non selfie version of top content and upload section,
                no ipp option section' do
              verify_handoff_page_non_selfie_version_content(page)
              verify_handoff_page_no_ipp_option_shown(page)
              verify_upload_photos_section_and_link(page)
            end
          end
        end
      end

      context 'when ipp opt in is disabled' do
        let(:in_person_proofing_opt_in_enabled) { false }
        context 'when sp ipp is enabled' do
          let(:sp_ipp_enabled) { true }
          describe 'when selfie is required by sp' do
            let(:facial_match_required) { true }
            it 'shows selfie version of top content, no upload section,
                no ipp option section' do
              verify_handoff_page_selfie_version_content(page)
              verify_handoff_page_no_ipp_option_shown(page)
              verify_no_upload_photos_section_and_link(page)
            end
          end
          describe 'when selfie is not required by sp' do
            let(:facial_match_required) { false }
            it 'shows non selfie version of top content and upload section,
                no ipp option section' do
              verify_handoff_page_non_selfie_version_content(page)
              verify_handoff_page_no_ipp_option_shown(page)
              verify_upload_photos_section_and_link(page)
            end
          end
        end
        context 'when sp ipp is not enabled' do
          let(:sp_ipp_enabled) { false }
          describe 'when selfie required by sp' do
            let(:facial_match_required) { true }
            it 'shows selfie version of top content, no upload section,
                no ipp option section' do
              verify_handoff_page_selfie_version_content(page)
              verify_handoff_page_no_ipp_option_shown(page)
              verify_no_upload_photos_section_and_link(page)
            end
          end
          describe 'when selfie not required by sp' do
            let(:facial_match_required) { false }
            it 'shows non selfie version of top content and upload section,
                no ipp option section' do
              verify_handoff_page_non_selfie_version_content(page)
              verify_handoff_page_no_ipp_option_shown(page)
              verify_upload_photos_section_and_link(page)
            end
          end
        end
      end
    end
  end
end
