require 'rails_helper'
require 'action_account'
require 'axe-rspec'

RSpec.describe 'In Person Proofing Threatmetrix', js: true do
  include InPersonHelper

  let(:sp) { :oidc }
  let(:user) { user_with_2fa }
  let(:enrollment_code) do
    JSON.parse(
      UspsInPersonProofing::Mock::Fixtures.request_enroll_response,
    )['enrollmentCode']
  end
  let(:stdout) { StringIO.new }
  let(:stderr) { StringIO.new }
  let(:argv) { ['review-pass', user.uuid, '--reason', 'INV1234'] }
  let(:action_account) { ActionAccount.new(argv:, stdout:, stderr:) }
  let(:review_pass) { ActionAccount::ReviewPass.new }
  let(:review_reject) { ActionAccount::ReviewReject.new }
  let(:include_missing) { true }
  let(:config) { ScriptBase::Config.new(include_missing:, reason: 'INV1234') }
  let(:enrollment) { InPersonEnrollment.last }
  let(:profile) { enrollment.profile }
  let(:service_provider) { ServiceProvider.find_by(issuer: service_provider_issuer(sp)) }

  before do
    allow(IdentityConfig.store).to receive(:in_person_proofing_enabled).and_return(true)
    allow(IdentityConfig.store).to receive(:in_person_proofing_enforce_tmx).and_return(true)
    service_provider.update(in_person_proofing_enabled: true)
  end

  def deactivate_profile_update_enrollment(status:)
    # set fraud review to pending:
    profile.deactivate_for_fraud_review
    # update the enrollment:
    enrollment.update(
      status: status,
      proofed_at: Time.zone.now,
      status_check_completed_at: Time.zone.now,
    )
    profile.reload
    enrollment.reload
  end

  shared_examples_for 'initially shows the user the barcode page' do
    it 'shows the user the barcode page', allow_browser_log: true do
      expect_in_person_step_indicator_current_step(
        t('step_indicator.flows.idv.go_to_the_post_office'),
      )
      expect(page).to have_content(strip_nbsp(t('in_person_proofing.headings.barcode')))
      expect(page).to have_content(Idv::InPerson::EnrollmentCodeFormatter.format(enrollment_code))
      expect(page).to have_current_path(idv_in_person_ready_to_verify_path)
    end
  end

  shared_examples_for 'shows the user the Please Call screen' do
    it 'shows the user the Please Call screen after passing IPP', allow_browser_log: true do
      Capybara.reset_session!
      sign_in_live_with_2fa(user)
      expect(page).to have_current_path(account_path)
      visit_idp_from_sp_with_ial2(sp)
      expect(page).to have_current_path(idv_in_person_ready_to_verify_path)

      deactivate_profile_update_enrollment(status: :passed)
      expect(page).to have_current_path(idv_in_person_ready_to_verify_path)
      page.refresh
      expect(page).to have_current_path(idv_please_call_path)
    end
  end

  context 'ThreatMetrix determination of Review' do
    let(:tmx_status) { 'Review' }

    it 'allows the user to continue down the happy path', allow_browser_log: true do
      visit_idp_from_sp_with_ial2(:oidc, **{ client_id: service_provider.issuer })
      sign_in_and_2fa_user(user)
      begin_in_person_proofing(user)
      # prepare page
      complete_prepare_step(user)

      # location page
      complete_location_step(user)

      # state ID page
      complete_state_id_controller(user)

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
        t(
          'in_person_proofing.body.barcode.deadline',
          deadline: deadline,
          sp_name: service_provider.friendly_name,
        ),
      )
      expect(page).to have_content('MILWAUKEE')
      expect(page).to have_content('Sunday: Closed')

      # signing in again before completing in-person proofing at a post office
      Capybara.reset_session!
      sign_in_live_with_2fa(user)
      visit_idp_from_sp_with_ial2(:oidc)
      expect(page).to have_current_path(idv_in_person_ready_to_verify_path)
    end

    it 'handles profiles in fraud review after 30 days', allow_browser_log: true do
      sign_in_and_2fa_user(user)
      begin_in_person_proofing(user)
      complete_prepare_step(user)
      complete_location_step
      complete_state_id_controller(user)

      # ssn page
      complete_ssn_step(user, tmx_status)
      complete_verify_step(user)
      complete_phone_step(user)
      complete_enter_password_step(user)
      acknowledge_and_confirm_personal_key

      profile = InPersonEnrollment.last.profile
      profile.deactivate_for_fraud_review
      expect(profile.fraud_review_pending_at).to be_truthy
      expect(profile.fraud_rejection_at).to eq(nil)
      profile.update(fraud_review_pending_at: 31.days.ago)
      FraudRejectionDailyJob.new.perform(Time.zone.now)

      # profile is rejected
      profile.reload
      expect(profile.fraud_review_pending_at).to be(nil)
      expect(profile.fraud_rejection_at).to be_truthy
    end

    context 'Fraud decisioning is completed' do
      before do
        complete_entire_ipp_flow(user, tmx_status)
      end

      context 'User passes IPP and passes TMX Review' do
        it_behaves_like 'initially shows the user the barcode page'

        it_behaves_like 'shows the user the Please Call screen'

        it 'does not allow the user to restart the IPP flow', allow_browser_log: true do
          deactivate_profile_update_enrollment(status: :passed)

          visit_idp_from_sp_with_ial2(sp)
          expect(page).to have_current_path(idv_please_call_path)
          page.visit(idv_welcome_path)
          expect(page).to have_current_path(idv_please_call_path)
          page.visit(idv_in_person_state_id_path)
          expect(page).to have_current_path(idv_please_call_path)
        end

        it 'shows the user the successful verification screen after passing TMX review',
           allow_browser_log: true do
          deactivate_profile_update_enrollment(status: :passed)
          visit_idp_from_sp_with_ial2(sp)
          expect(page).to have_current_path(idv_please_call_path)

          expect do
            review_pass.run(args: [user.uuid], config:)
          end.to(change { ActionMailer::Base.deliveries.count }.by(1))
          page.visit(idv_welcome_path)
          expect(page).to have_current_path(idv_activated_path)
        end
      end

      context 'User passes IPP and fails TMX Review' do
        it_behaves_like 'initially shows the user the barcode page'

        it_behaves_like 'shows the user the Please Call screen'

        it 'does not allow the user to restart the flow', allow_browser_log: true do
          deactivate_profile_update_enrollment(status: :passed)

          # user revisits before fraud rejection
          visit_idp_from_sp_with_ial2(sp)
          expect(page).to have_current_path(idv_please_call_path)

          # reject the user
          expect do
            review_reject.run(args: [user.uuid], config:)
          end.to(change { ActionMailer::Base.deliveries.count }.by(1))

          # user revisits after fraud rejection
          visit_idp_from_sp_with_ial2(sp)
          expect(page).to have_current_path(idv_not_verified_path)
        end
      end

      context 'User fails IPP and fails TMX review' do
        it_behaves_like 'initially shows the user the barcode page'

        it 'allows the user to restart the flow', allow_browser_log: true do
          deactivate_profile_update_enrollment(status: :failed)

          visit_idp_from_sp_with_ial2(sp)
          # user should not see the please call page as they failed ipp
          expect(page).not_to have_current_path(idv_please_call_path)
          # redo the flow:
          complete_entire_ipp_flow(user, tmx_status)
          expect(page).to have_current_path(idv_in_person_ready_to_verify_path)
        end
      end

      context 'User cancels IPP after being deactivated for TMX review',
              allow_browser_log: true do
        it 'allows the user to restart IPP' do
          # set fraud review to pending:
          profile.deactivate_for_fraud_review
          profile.reload

          # cancel the enrollment
          click_link t('links.cancel')
          # user can restart
          click_on t('idv.cancel.actions.start_over')

          # user should be redirected to the welcome path when they cancel
          expect(page).to have_current_path(idv_welcome_path)
        end
      end
    end
  end

  context 'ThreatMetrix determination of Reject' do
    let(:tmx_status) { 'Reject' }

    before do
      complete_entire_ipp_flow(user, tmx_status)
    end

    context 'User passes IPP and rejects for TMX review' do
      it_behaves_like 'initially shows the user the barcode page'

      it_behaves_like 'shows the user the Please Call screen'

      it 'does not allow the user to restart the IPP flow', allow_browser_log: true do
        deactivate_profile_update_enrollment(status: :passed)

        # reject the user
        expect do
          review_reject.run(args: [user.uuid], config:)
        end.to(change { ActionMailer::Base.deliveries.count }.by(1))

        visit_idp_from_sp_with_ial2(sp)
        expect(page).to have_current_path(idv_not_verified_path)
        page.visit(idv_welcome_path)
        expect(page).to have_current_path(idv_not_verified_path)
        page.visit(idv_in_person_state_id_path)
        expect(page).to have_current_path(idv_not_verified_path)
      end
    end
  end
end
