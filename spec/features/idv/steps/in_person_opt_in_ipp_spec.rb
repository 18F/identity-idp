require 'rails_helper'
require 'axe-rspec'

RSpec.describe 'In Person Proofing - Opt-in IPP ', js: true do
  include IdvStepHelper
  include SpAuthHelper
  include InPersonHelper
  org = 'test_org'

  let(:ipp_service_provider) { create(:service_provider, :active, :in_person_proofing_enabled) }
  let(:user) { user_with_2fa }

  before do
    allow(IdentityConfig.store).to receive(:in_person_proofing_enabled).and_return(true)
    allow(IdentityConfig.store).to receive(:in_person_proofing_opt_in_enabled).and_return(true)
    allow(IdentityConfig.store).to receive(:otp_delivery_blocklist_maxretry).and_return(5)
  end

  context 'when ipp_opt_in_enabled and ipp_opt_in_enabled are both enabled' do
    context 'ThreatMetrix review pending' do
      before do
        allow(IdentityConfig.store).to receive(:proofing_device_profiling).and_return(:enabled)
        allow(IdentityConfig.store).to receive(:lexisnexis_threatmetrix_org_id).and_return(org)
        allow_any_instance_of(ServiceProvider).to receive(:in_person_proofing_enabled).
          and_return(true)
      end

      it 'allows the user to continue down the happy path selecting to opt in',
         allow_browser_log: true do
        visit_idp_from_sp_with_ial2(:oidc, **{ client_id: ipp_service_provider.issuer })
        sign_in_via_branded_page(user)

        # complete welcome step, agreement step, how to verify step (and opts into Opt-in Ipp)
        begin_in_person_proofing_with_opt_in_ipp_enabled_and_opting_in

        # prepare page
        complete_prepare_step(user)

        # location page
        complete_location_step

        # state ID page
        complete_state_id_controller(user)

        # ssn page
        select 'Reject', from: :mock_profiling_result
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
        expect(page).to have_text(
          Idp::Constants::MOCK_IDV_APPLICANT_STATE_ID_JURISDICTION,
          count: 1,
        )
        expect(page).to have_text(
          Idp::Constants::MOCK_IDV_APPLICANT_STATE,
          count: 2,
        )
        expect(page).to have_text(InPersonHelper::GOOD_IDENTITY_DOC_ZIPCODE).twice
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
        expect_in_person_step_indicator_current_step(
          t('step_indicator.flows.idv.re_enter_password'),
        )
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
            IdentityConfig.store.in_person_enrollment_validity_in_days.days).
            in_time_zone(Idv::InPerson::ReadyToVerifyPresenter::USPS_SERVER_TIMEZONE).
            strftime(t('time.formats.event_date'))
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
        visit_idp_from_sp_with_ial2(:oidc, **{ client_id: ipp_service_provider.issuer })
        sign_in_via_branded_page(user)
        expect(page).to have_current_path(idv_in_person_ready_to_verify_path)
      end
    end

    it 'works for a happy path when the user opts into opt-in ipp',
       allow_browser_log: true do
      visit_idp_from_sp_with_ial2(:oidc, **{ client_id: ipp_service_provider.issuer })
      sign_in_via_branded_page(user)

      # complete welcome step, agreement step, how to verify step (and opts into Opt-in Ipp)
      begin_in_person_proofing_with_opt_in_ipp_enabled_and_opting_in

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
      expect(page).to have_text(
        Idp::Constants::MOCK_IDV_APPLICANT_STATE_ID_JURISDICTION,
        count: 1,
      )
      expect(page).to have_text(
        Idp::Constants::MOCK_IDV_APPLICANT_STATE,
        count: 2,
      )
      expect(page).to have_text(InPersonHelper::GOOD_IDENTITY_DOC_ZIPCODE).twice
      expect(page).to have_text(DocAuthHelper::GOOD_SSN_MASKED)

      # click update state ID button
      click_link t('idv.buttons.change_state_id_label')
      expect(page).to have_content(t('in_person_proofing.headings.update_state_id'))
      choose t('in_person_proofing.form.state_id.same_address_as_id_yes')
      click_button t('forms.buttons.submit.update')
      expect(page).to have_content(t('headings.verify'))
      expect(page).to have_current_path(idv_in_person_verify_info_path)

      # click update address button
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
        deadline =
          (Time.zone.now + IdentityConfig.store.in_person_enrollment_validity_in_days.days).
            in_time_zone(Idv::InPerson::ReadyToVerifyPresenter::USPS_SERVER_TIMEZONE).
            strftime(t('time.formats.event_date'))
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
      expect(page).to have_content(
        t(
          'in_person_proofing.body.barcode.deadline',
          deadline: deadline,
        ),
      )
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

    context 'when the service provider does not participate in IPP',
            allow_browser_log: true do
      before do
        allow(IdentityConfig.store).to receive(:proofing_device_profiling).and_return(:enabled)
        allow(IdentityConfig.store).to receive(:lexisnexis_threatmetrix_org_id).and_return(org)
        allow_any_instance_of(ServiceProvider).to receive(:in_person_proofing_enabled).
          and_return(false)
      end

      it 'skips how to verify and goes to hybrid_handoff' do
        sign_in_and_2fa_user(user)
        visit_idp_from_sp_with_ial2(:oidc)
        complete_welcome_step
        complete_agreement_step
        expect(page).to have_current_path(idv_hybrid_handoff_url)
      end
    end

    it 'works for a happy path when the user opts out of opt-in ipp',
       allow_browser_log: true do
      visit_idp_from_sp_with_ial2(:oidc, **{ client_id: ipp_service_provider.issuer })
      sign_in_via_branded_page(user)

      # complete welcome step, agreement step, how to verify step (and opts out of Opt-in Ipp)
      begin_in_person_proofing_with_opt_in_ipp_enabled_and_opting_out

      # hybrid handoff
      click_on t('forms.buttons.upload_photos')
      mock_doc_auth_attention_with_barcode

      # doc auth- attach and submit images to fail doc auth
      mock_doc_auth_attention_with_barcode
      attach_images
      submit_images

      # pick in-person proofing (now that you failed doc auth, this is NOT opting in
      # because it was not picked on how to verify page)
      click_button t('in_person_proofing.body.cta.button')

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
      expect(page).to have_text(
        Idp::Constants::MOCK_IDV_APPLICANT_STATE_ID_JURISDICTION,
        count: 1,
      )
      expect(page).to have_text(
        Idp::Constants::MOCK_IDV_APPLICANT_STATE,
        count: 2,
      )
      expect(page).to have_text(InPersonHelper::GOOD_IDENTITY_DOC_ZIPCODE).twice
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
        deadline =
          (Time.zone.now + IdentityConfig.store.in_person_enrollment_validity_in_days.days).
            in_time_zone(Idv::InPerson::ReadyToVerifyPresenter::USPS_SERVER_TIMEZONE).
            strftime(t('time.formats.event_date'))
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
      expect(page).to have_content(
        t(
          'in_person_proofing.body.barcode.deadline',
          deadline: deadline,
        ),
      )
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
  end

  context 'when ipp_enabled is false and ipp_opt_in_enabled is true' do
    let(:sp) { :oidc }

    before do
      allow(IdentityConfig.store).to receive(:in_person_proofing_enabled) { false }
      allow(IdentityConfig.store).to receive(:in_person_proofing_opt_in_enabled) { true }
      allow_any_instance_of(ServiceProvider).to receive(:in_person_proofing_enabled).
        and_return(true)
    end

    it 'skips how to verify and continues along the normal path' do
      sign_in_and_2fa_user(user)
      visit_idp_from_sp_with_ial2(:oidc)
      complete_welcome_step
      complete_agreement_step
      expect(page).to have_current_path(idv_hybrid_handoff_url)
      complete_hybrid_handoff_step
      complete_document_capture_step
      complete_ssn_step
      complete_verify_step
      complete_phone_step(user)
      complete_enter_password_step(user)
      acknowledge_and_confirm_personal_key
    end

    it 'works properly along the normal path when in_person_proofing_enabled is true' do
      allow(IdentityConfig.store).to receive(:in_person_proofing_enabled) { true }
      visit_idp_from_sp_with_ial2(:oidc, **{ client_id: ipp_service_provider.issuer })
      sign_in_via_branded_page(user)
      complete_welcome_step
      complete_agreement_step
      click_on t('forms.buttons.continue_remote')
      expect(page).to have_current_path(idv_hybrid_handoff_url)
      complete_hybrid_handoff_step
      complete_document_capture_step
      complete_ssn_step
      complete_verify_step
      complete_phone_step(user)
      complete_enter_password_step(user)
      acknowledge_and_confirm_personal_key
    end
  end
end
