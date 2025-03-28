require 'rails_helper'
require 'axe-rspec'

RSpec.describe 'In Person Proofing', js: true do
  include IdvStepHelper
  include SpAuthHelper
  include InPersonHelper
  include UspsIppHelper

  let(:ipp_service_provider) { create(:service_provider, :active, :in_person_proofing_enabled) }
  let(:user) { user_with_2fa }

  before do
    allow(IdentityConfig.store).to receive(:in_person_proofing_enabled).and_return(true)
    allow(IdentityConfig.store).to receive(:in_person_completion_survey_delivery_enabled)
      .and_return(true)
  end

  it 'works for a happy path', allow_browser_log: true do
    user = user_with_2fa

    sign_in_and_2fa_user(user)
    begin_in_person_proofing(user)

    # prepare page
    expect(page).to(have_content(t('in_person_proofing.body.prepare.verify_step_about')))
    expect_in_person_step_indicator_current_step(t('step_indicator.flows.idv.find_a_post_office'))
    complete_prepare_step(user)

    # location page
    expect_in_person_step_indicator_current_step(t('step_indicator.flows.idv.find_a_post_office'))
    expect(page).to have_content(t('in_person_proofing.headings.po_search.location'))
    complete_location_step

    # state ID page
    expect_in_person_step_indicator_current_step(
      t('step_indicator.flows.idv.verify_info'),
    )
    expect(page).to have_content(
      strip_nbsp(
        t(
          'in_person_proofing.headings.state_id_milestone_2',
        ),
      ),
    )
    complete_state_id_controller(user)

    # ssn page
    expect_in_person_step_indicator_current_step(t('step_indicator.flows.idv.verify_info'))
    expect(page).to have_content(t('doc_auth.headings.ssn'))
    complete_ssn_step(user)

    # verify page
    expect_in_person_step_indicator_current_step(t('step_indicator.flows.idv.verify_info'))
    expect(page).to have_content(t('headings.verify'))
    expect(page).to have_current_path(idv_in_person_verify_info_path)
    expect(page).to have_text(InPersonHelper::GOOD_FIRST_NAME)
    expect(page).to have_text(InPersonHelper::GOOD_LAST_NAME)
    expect(page).to have_text(InPersonHelper::GOOD_DOB_FORMATTED_EVENT)
    expect(page).to have_text(InPersonHelper::GOOD_STATE_ID_NUMBER)
    expect(page).to have_text(InPersonHelper::GOOD_IDENTITY_DOC_ADDRESS1).twice
    expect(page).to have_text(InPersonHelper::GOOD_IDENTITY_DOC_ADDRESS2).twice
    expect(page).to have_text(InPersonHelper::GOOD_IDENTITY_DOC_CITY).twice
    expect(page).to have_text(Idp::Constants::MOCK_IDV_APPLICANT_STATE_ID_JURISDICTION, count: 1)
    expect(page).to have_text(Idp::Constants::MOCK_IDV_APPLICANT_STATE, count: 2)
    expect(page).to have_text(InPersonHelper::GOOD_IDENTITY_DOC_ZIPCODE).twice
    expect(page).to have_text(DocAuthHelper::GOOD_SSN_MASKED)

    # click update state ID button
    click_link t('idv.buttons.change_state_id_label')

    expect(page).to have_content(t('in_person_proofing.headings.update_state_id'))

    choose t('in_person_proofing.form.state_id.same_address_as_id_yes')
    click_button t('forms.buttons.submit.update')
    expect(page).to have_content(t('headings.verify'))
    expect(page).to have_current_path(idv_in_person_verify_info_path)

    # click update address link
    click_link t('idv.buttons.change_address_label')
    expect(page).to have_content(t('in_person_proofing.headings.update_address'))
    click_button t('forms.buttons.submit.update')
    expect(page).to have_content(t('headings.verify'))
    expect(page).to have_current_path(idv_in_person_verify_info_path)

    # click update ssn button
    click_on t('idv.buttons.change_ssn_label')
    expect(page).to have_content(t('doc_auth.headings.ssn_update'))
    fill_out_ssn_form_ok
    click_button t('forms.buttons.submit.update')
    expect(page).to have_content(t('headings.verify'))
    expect(page).to have_current_path(idv_in_person_verify_info_path)
    complete_verify_step(user)

    # phone page
    expect_in_person_step_indicator_current_step(
      t('step_indicator.flows.idv.verify_phone'),
    )
    expect(page).to have_content(t('titles.idv.phone'))
    fill_out_phone_form_ok(MfaContext.new(user).phone_configurations.first.phone)
    click_idv_send_security_code
    expect_in_person_step_indicator_current_step(
      t('step_indicator.flows.idv.verify_phone'),
    )

    expect_in_person_step_indicator_current_step(
      t('step_indicator.flows.idv.verify_phone'),
    )
    fill_in_code_with_last_phone_otp
    click_submit_default

    # password confirm page
    expect_in_person_step_indicator_current_step(t('step_indicator.flows.idv.re_enter_password'))
    expect(page).to have_content(t('idv.titles.session.enter_password', app_name: APP_NAME))
    complete_enter_password_step(user)

    # personal key page
    expect_in_person_step_indicator_current_step(
      t('step_indicator.flows.idv.go_to_the_post_office'),
    )
    expect(page).to have_content(t('titles.idv.personal_key'))
    deadline = nil
    freeze_time do
      acknowledge_and_confirm_personal_key
      deadline = (Time.zone.now + IdentityConfig.store.in_person_enrollment_validity_in_days.days)
        .in_time_zone(Idv::InPerson::ReadyToVerifyPresenter::USPS_SERVER_TIMEZONE)
        .strftime(t('time.formats.event_date'))
    end

    # ready to verify page
    expect_in_person_step_indicator_current_step(
      t('step_indicator.flows.idv.go_to_the_post_office'),
    )
    expect_page_to_have_no_accessibility_violations(page)
    enrollment_code = JSON.parse(
      UspsInPersonProofing::Mock::Fixtures.request_enroll_response,
    )['enrollmentCode']
    expect(page).to have_css("img[alt='#{APP_NAME}']")
    expect(page).to have_content(strip_nbsp(t('in_person_proofing.headings.barcode')))
    expect(page).to have_content(Idv::InPerson::EnrollmentCodeFormatter.format(enrollment_code))
    expect(page).to have_content(t('in_person_proofing.body.barcode.deadline', deadline: deadline))
    expect(page).to have_content('MILWAUKEE')
    expect(page).to have_content('Sunday: Closed')

    # signing in again before completing in-person proofing at a post office
    Capybara.reset_session!
    sign_in_live_with_2fa(user)
    visit_idp_from_sp_with_ial2(:oidc)
    expect(page).to have_current_path(idv_in_person_ready_to_verify_path)

    # confirm that user cannot visit other IdV pages before completing in-person proofing
    visit idv_agreement_path
    expect(page).to have_current_path(idv_in_person_ready_to_verify_path)
    visit idv_ssn_url
    expect(page).to have_current_path(idv_in_person_ready_to_verify_path)
    visit idv_verify_info_url
    expect(page).to have_current_path(idv_in_person_ready_to_verify_path)

    # Confirms that user can visit account page even if not completing in person proofing
    Capybara.reset_session!
    sign_in_and_2fa_user(user)
    expect(page).to have_current_path(account_path)
  end

  it 'allows the user to cancel and start over from the beginning', allow_browser_log: true do
    user = sign_in_and_2fa_user
    begin_in_person_proofing
    complete_all_in_person_proofing_steps
    complete_phone_step(user)
    complete_enter_password_step(user)
    acknowledge_and_confirm_personal_key

    click_link t('links.cancel')
    click_on t('idv.cancel.actions.start_over')

    expect(page).to have_current_path(idv_welcome_path)
    begin_in_person_proofing
    complete_all_in_person_proofing_steps
  end

  it 'allows the user to go back to document capture from location step', allow_browser_log: true do
    sign_in_and_2fa_user
    begin_in_person_proofing
    complete_prepare_step
    search_for_post_office
    expect(page).to have_css('.location-collection-item', wait: 10)
    # back to prepare page
    click_button t('forms.buttons.back')
    expect(page).to have_content(t('in_person_proofing.headings.prepare'))

    # back to doc capture page
    click_button t('forms.buttons.back')

    # Note: This is specifically for failed barcodes. Other cases may use
    #      "idv.failure.button.warning" instead.
    expect(page).to have_button(t('doc_auth.buttons.add_new_photos'))
    click_button t('doc_auth.buttons.add_new_photos')

    expect(page).to have_content(t('doc_auth.headings.review_issues'))

    # Images should still be present
    expect(page).to have_text('logo.png', count: 2)
  end

  context 'after in-person proofing is completed and passed for a partner' do
    let(:sp) { nil }
    before do
      create_in_person_ial2_account_go_back_to_sp_and_sign_out(sp)
    end

    [
      :oidc,
      :saml,
    ].each do |service_provider|
      context "using #{service_provider}" do
        let(:sp) { service_provider }
        it 'sends a survey when they share information with that partner',
           allow_browser_log: true do
          expect(last_email.html_part.body)
            .to have_selector(
              "a[href='#{IdentityConfig.store.in_person_opt_in_available_completion_survey_url}']",
            )
        end
      end
    end
  end

  context 'the user fails remote docauth and starts IPP', allow_browser_log: true do
    before do
      allow(IdentityConfig.store).to receive(:in_person_proofing_opt_in_enabled).and_return(true)

      visit_idp_from_sp_with_ial2(:oidc, **{ client_id: ipp_service_provider.issuer })
      sign_in_via_branded_page(user)
      complete_doc_auth_steps_before_document_capture_step(expect_accessible: true)

      # Fail docauth
      complete_document_capture_step_with_yml(
        'spec/fixtures/ial2_test_credential_multiple_doc_auth_failures_both_sides.yml',
        expected_path: idv_document_capture_url,
      )

      # begin in-person proofing
      find(:button, t('in_person_proofing.body.cta.button'), wait: 10).click
      complete_prepare_step
      complete_location_step
    end

    context 'then navigates back to the submit images page and resumes remote
    with successful images' do
      it 'allows the user to successfully complete remote identity verification' do
        # Click back and resume remote identity verification
        visit idv_document_capture_url
        complete_document_capture_step(with_selfie: false)

        complete_remote_idv_from_ssn(user)
      end
    end

    context 'then navigates to how to verify and resumes remote with successful images' do
      it 'allows the user to successfully complete remote identity verification' do
        complete_state_id_controller(user)
        # Change mind and resume remote identity verification
        visit idv_how_to_verify_url

        # choose remote
        click_on t('forms.buttons.continue_online')
        complete_hybrid_handoff_step
        complete_document_capture_step(with_selfie: false)

        complete_remote_idv_from_ssn(user)
      end
    end
  end

  context 'the user starts in-person proofing then navigates back to how to verify' do
    before do
      allow(IdentityConfig.store).to receive(:in_person_proofing_opt_in_enabled).and_return(true)

      # Begin identity verification via in-person proofing
      visit_idp_from_sp_with_ial2(:oidc, **{ client_id: ipp_service_provider.issuer })
      sign_in_via_branded_page(user)
      begin_in_person_proofing_with_opt_in_ipp_enabled_and_opting_in
      complete_prepare_step
      complete_location_step
      complete_state_id_controller(user)
      complete_ssn_step(user)
      expect_in_person_step_indicator_current_step(t('step_indicator.flows.idv.verify_info'))

      # Change mind and start remote identity verification
      visit idv_how_to_verify_url
    end

    it 'allows the user to successfully complete remote identity verification' do
      # choose remote
      click_on t('forms.buttons.continue_online')
      complete_hybrid_handoff_step
      complete_document_capture_step(with_selfie: false)

      complete_remote_idv_from_ssn(user)
    end
  end

  context 'with hybrid document capture' do
    before do
      allow(FeatureManagement).to receive(:doc_capture_polling_enabled?).and_return(true)
      allow(Telephony).to receive(:send_doc_auth_link).and_wrap_original do |impl, config|
        @sms_link = config[:link]
        impl.call(**config)
      end
    end

    it 'resumes desktop session with in-person proofing when same_address_as_id is true',
       allow_browser_log: true do
      user = nil

      perform_in_browser(:desktop) do
        user = sign_in_and_2fa_user
        complete_doc_auth_steps_before_hybrid_handoff_step
        clear_and_fill_in(:doc_auth_phone, '415-555-0199')
        click_send_link

        expect(page).to have_content(t('doc_auth.headings.text_message'))
      end

      expect(@sms_link).to be_present

      perform_mobile_hybrid_steps
      perform_desktop_hybrid_steps(user)
    end

    it 'resumes desktop session with in-person proofing when same_address_as_id is false',
       allow_browser_log: true do
      user = nil

      perform_in_browser(:desktop) do
        user = sign_in_and_2fa_user
        complete_doc_auth_steps_before_hybrid_handoff_step
        clear_and_fill_in(:doc_auth_phone, '415-555-0199')
        click_send_link

        expect(page).to have_content(t('doc_auth.headings.text_message'))
      end

      expect(@sms_link).to be_present

      perform_mobile_hybrid_steps
      perform_desktop_hybrid_steps(user, same_address_as_id: false)
    end

    context 'when the user fails docauth remote in the hybrid flow and begins IPP' do
      before do
        allow(IdentityConfig.store).to receive(:in_person_proofing_opt_in_enabled).and_return(true)

        perform_in_browser(:desktop) do
          visit_idp_from_sp_with_ial2(:oidc, **{ client_id: ipp_service_provider.issuer })
          sign_in_via_branded_page(user)
          complete_doc_auth_steps_before_hybrid_handoff_step

          # choose remote
          click_on t('forms.buttons.continue_online')
          click_send_link

          expect(page).to have_content(t('doc_auth.headings.text_message'))
        end

        perform_mobile_hybrid_steps
      end

      context 'then the user navigates to the how to verify page and changes from IPP to remote
      verification after returning to desktop' do
        it 'allows the user to successfully complete remote identity verification' do
          perform_in_browser(:desktop) do
            # Change mind and resume remote identity verification
            visit idv_how_to_verify_url

            # choose remote
            click_on t('forms.buttons.continue_online')
            complete_hybrid_handoff_step
            successful_response = instance_double(
              Faraday::Response,
              status: 200,
              body: LexisNexisFixtures.true_id_response_success,
            )
            DocAuth::Mock::DocAuthMockClient.mock_response!(
              method: :get_results,
              response: DocAuth::LexisNexis::Responses::TrueIdResponse.new(
                successful_response,
                DocAuth::LexisNexis::Config.new,
              ),
            )
            complete_document_capture_step(with_selfie: false)

            complete_remote_idv_from_ssn(user)
          end
        end
      end

      context 'then navigates back to the hybrid handoff page and selects remote verification
      via the hybrid flow' do
        it 'allows the user to successfully complete remote identity verification',
           allow_browser_log: true do
          # click back link while on the state id page
          perform_in_browser(:desktop) do
            visit idv_hybrid_handoff_url
            click_send_link

            # Test that user stays on the link sent page
            sleep(5)
            expect(page).to(have_content(t('doc_auth.headings.text_message')))

            # Test that user doesn't automatically get moved forward to the state id page on desktop
            expect(page).not_to(have_content(t('in_person_proofing.headings.state_id_milestone_2')))
          end
        end
      end
    end

    context 'when polling times out and the user has to click the "Continue" button' do
      before do
        # When polling times out on the client, the "Continue" button is displayed to the user
        # We can simulate that by just completely disabling polling.
        allow(FeatureManagement).to receive(:doc_capture_polling_enabled?).and_return(false)
      end

      it 'redirects the user to the in-person proofing path',
         allow_browser_log: true do
        user = nil
        perform_in_browser(:desktop) do
          user = sign_in_and_2fa_user
          complete_doc_auth_steps_before_hybrid_handoff_step
          clear_and_fill_in(:doc_auth_phone, '415-555-0199')
          click_send_link

          expect(page).to have_content(t('doc_auth.headings.text_message'))
        end

        expect(@sms_link).to be_present

        perform_mobile_hybrid_steps

        perform_in_browser(:desktop) do
          expect(page).to have_current_path(idv_link_sent_path)

          # Click the "Continue" button on the link sent page since we're not polling
          click_idv_continue
        end

        perform_desktop_hybrid_steps(user)
      end
    end
  end

  context 'verify by mail not allowed for in-person' do
    it 'does not present gpo as an option', allow_browser_log: true do
      sign_in_and_2fa_user
      begin_in_person_proofing
      complete_all_in_person_proofing_steps
      expect(page).to have_current_path(idv_phone_path)
      expect(page).not_to have_content(t('idv.troubleshooting.options.verify_by_mail'))
    end
  end

  context 'same address as id is false',
          allow_browser_log: true do
    let(:user) { user_with_2fa }

    before(:each) do
      sign_in_and_2fa_user(user)
      begin_in_person_proofing(user)
      complete_prepare_step(user)
      complete_location_step(user)
    end

    it 'shows the address page' do
      complete_state_id_controller(user, same_address_as_id: false)
      expect_in_person_step_indicator_current_step(t('step_indicator.flows.idv.verify_info'))
      expect(page).to have_content(t('in_person_proofing.headings.address'))

      # arrive at address step
      complete_address_step(user, same_address_as_id: false)
      complete_ssn_step(user)

      # Ensure the page submitted successfully
      expect(page).to have_content(t('idv.form.ssn_label'))
    end

    it 'can update the address page form' do
      complete_state_id_controller(user, same_address_as_id: false)
      complete_address_step(user, same_address_as_id: false)
      complete_ssn_step(user)
      # click update address link on the verify page
      click_link t('idv.buttons.change_address_label')
      expect(page).to have_content(t('in_person_proofing.headings.update_address'))
      fill_out_address_form_ok(same_address_as_id: true)
      click_button t('forms.buttons.submit.update')
      expect(page).to have_content(t('headings.verify'))
      expect(page).to have_current_path(idv_in_person_verify_info_path)
    end
  end

  context 'same address as id is true',
          allow_browser_log: true do
    let(:user) { user_with_2fa }

    before(:each) do
      sign_in_and_2fa_user(user)
      begin_in_person_proofing(user)
      complete_prepare_step(user)
      complete_location_step(user)
    end

    it 'allows user to update their residential address as different from their state id' do
      complete_state_id_controller(user, same_address_as_id: true)
      # skip address step b/c residential address is same as state id address
      complete_ssn_step(user)

      # click "update residential address"
      click_link t('idv.buttons.change_address_label')
      expect(page).to have_content(t('in_person_proofing.headings.update_address'))
      # expect address page to have fields populated with address from state id
      expect(page).to have_field(
        t('idv.form.address1'),
        with: InPersonHelper::GOOD_IDENTITY_DOC_ADDRESS1,
      )

      # change part of the address
      fill_in t('idv.form.address1'), with: 'new address different from state address1'
      # click update
      click_button t('forms.buttons.submit.update')

      # verify page
      expect(page).to have_current_path(idv_in_person_verify_info_path)
      expect(page).to have_content(t('headings.verify'))
      expect(page).to have_text('new address different from state address1').once

      # click update state id address
      click_link t('idv.buttons.change_state_id_label')

      # check that the "No, I live at a different address" is checked
      expect(page).to have_checked_field(
        t('in_person_proofing.form.state_id.same_address_as_id_no'),
        visible: false,
      )
    end
  end

  context 'Outage alert enabled' do
    let(:user) { user_with_2fa }

    before do
      allow(IdentityConfig.store).to receive(:in_person_outage_message_enabled).and_return(true)
    end

    it 'allows the user to generate a barcode despite outage', allow_browser_log: true do
      sign_in_and_2fa_user(user)
      begin_in_person_proofing(user)

      # alert is visible on prepare page
      expect(page).to have_content(
        t(
          'idv.failure.exceptions.in_person_outage_error_message.post_cta.body',
          app_name: APP_NAME,
        ),
      )
      complete_all_in_person_proofing_steps
      complete_phone_step(user)
      complete_enter_password_step(user)
      acknowledge_and_confirm_personal_key

      # alert is visible on ready to verify page
      expect(page).to have_content(
        t('idv.failure.exceptions.in_person_outage_error_message.ready_to_verify.body'),
      )
      expect(page).to have_current_path(idv_in_person_ready_to_verify_path, wait: 10)
    end
  end

  context 'when full form address post office search' do
    let(:user) { user_with_2fa }

    it 'allows the user to search by full address', allow_browser_log: true do
      sign_in_and_2fa_user(user)
      begin_in_person_proofing(user)
      # prepare page
      complete_prepare_step(user)

      # location page
      complete_location_step

      # state ID page
      complete_state_id_controller(user, same_address_as_id: false)

      # address page
      complete_address_step(user, same_address_as_id: false)

      # ssn page
      complete_ssn_step(user, 'Reject')

      # verify page
      expect_in_person_step_indicator_current_step(t('step_indicator.flows.idv.verify_info'))
      expect(page).to have_content(t('headings.verify'))
      expect(page).to have_current_path(idv_in_person_verify_info_path)
      expect(page).to have_text(InPersonHelper::GOOD_FIRST_NAME)
      expect(page).to have_text(InPersonHelper::GOOD_LAST_NAME)
      expect(page).to have_text(InPersonHelper::GOOD_DOB_FORMATTED_EVENT)
      expect(page).to have_text(InPersonHelper::GOOD_STATE_ID_NUMBER)
      expect(page).to have_text(InPersonHelper::GOOD_IDENTITY_DOC_ADDRESS1)
      expect(page).to have_text(InPersonHelper::GOOD_IDENTITY_DOC_ADDRESS2)
      expect(page).to have_text(InPersonHelper::GOOD_IDENTITY_DOC_CITY)
      expect(page).to have_text(Idp::Constants::MOCK_IDV_APPLICANT_STATE_ID_JURISDICTION).once
      expect(page).to have_text(Idp::Constants::MOCK_IDV_APPLICANT_STATE).twice
      expect(page).to have_text(InPersonHelper::GOOD_IDENTITY_DOC_ZIPCODE)
      expect(page).to have_text(InPersonHelper::GOOD_ADDRESS1)
      expect(page).to have_text(InPersonHelper::GOOD_CITY)
      expect(page).to have_text(InPersonHelper::GOOD_ZIPCODE)
      expect(page).to have_text(Idp::Constants::MOCK_IDV_APPLICANT_STATE)
      expect(page).to have_text(DocAuthHelper::GOOD_SSN_MASKED)
      complete_verify_step(user)

      # phone page
      expect_in_person_step_indicator_current_step(
        t('step_indicator.flows.idv.verify_phone'),
      )
      expect(page).to have_content(t('titles.idv.phone'))
      fill_out_phone_form_ok(MfaContext.new(user).phone_configurations.first.phone)
      click_idv_send_security_code
      expect_in_person_step_indicator_current_step(
        t('step_indicator.flows.idv.verify_phone'),
      )

      expect_in_person_step_indicator_current_step(
        t('step_indicator.flows.idv.verify_phone'),
      )
      fill_in_code_with_last_phone_otp
      click_submit_default

      # password confirm page
      expect_in_person_step_indicator_current_step(t('step_indicator.flows.idv.re_enter_password'))
      expect(page).to have_content(t('idv.titles.session.enter_password', app_name: APP_NAME))
      complete_enter_password_step(user)

      # personal key page
      expect_in_person_step_indicator_current_step(
        t('step_indicator.flows.idv.go_to_the_post_office'),
      )
      expect(page).to have_content(t('titles.idv.personal_key'))
      deadline = nil
      freeze_time do
        acknowledge_and_confirm_personal_key
        deadline = (Time.zone.now +
          IdentityConfig.store.in_person_enrollment_validity_in_days.days)
          .in_time_zone(Idv::InPerson::ReadyToVerifyPresenter::USPS_SERVER_TIMEZONE)
          .strftime(t('time.formats.event_date'))
      end

      # ready to verify page
      expect_in_person_step_indicator_current_step(
        t('step_indicator.flows.idv.go_to_the_post_office'),
      )
      expect_page_to_have_no_accessibility_violations(page)
      enrollment_code = JSON.parse(
        UspsInPersonProofing::Mock::Fixtures.request_enroll_response,
      )['enrollmentCode']
      expect(page).to have_content(strip_nbsp(t('in_person_proofing.headings.barcode')))
      expect(page).to have_content(Idv::InPerson::EnrollmentCodeFormatter.format(enrollment_code))
      expect(page).to have_content(
        t('in_person_proofing.body.barcode.deadline', deadline: deadline),
      )
      expect(page).to have_content('MILWAUKEE')
      expect(page).to have_content('Sunday: Closed')

      # signing in again before completing in-person proofing at a post office
      Capybara.reset_session!
      sign_in_live_with_2fa(user)
      visit_idp_from_sp_with_ial2(:oidc)
      expect(page).to have_current_path(idv_in_person_ready_to_verify_path)
    end
  end

  context 'when the USPS enrollment fails during enter password' do
    before do
      user = user_with_2fa
      sign_in_and_2fa_user(user)
      begin_in_person_proofing(user)
      complete_prepare_step(user)
      complete_location_step
      # Causes the schedule USPS enrollment request to throw a bad request error
      complete_state_id_controller(user, first_name: 'usps client error')
      complete_ssn_step(user)
      complete_verify_step(user)
      fill_out_phone_form_ok(MfaContext.new(user).phone_configurations.first.phone)
      click_idv_send_security_code
      fill_in_code_with_last_phone_otp
      click_submit_default
      complete_enter_password_step(user)
    end

    it 'then an error displayed on the enter password page', allow_browser_log: true do
      expect_in_person_step_indicator_current_step(t('step_indicator.flows.idv.re_enter_password'))
      expect(page).to have_content(
        'There was an internal error processing your request. Please try again.',
      )
    end
  end
end
