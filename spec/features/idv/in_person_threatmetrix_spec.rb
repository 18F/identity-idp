require 'rails_helper'

RSpec.describe 'In Person Proofing Threatmetrix', js: true, allowed_extra_analytics: [:*] do
  include IdvStepHelper
  include SpAuthHelper
  include InPersonHelper

  let(:sp) { :oidc }
  let(:user) { user_with_2fa }
  let(:enrollment_code) {JSON.parse(
    UspsInPersonProofing::Mock::Fixtures.request_enroll_response,
    )['enrollmentCode']}

  before do
    allow(IdentityConfig.store).to receive(:in_person_proofing_enabled).and_return(true)
    allow(IdentityConfig.store).to receive(:in_person_proofing_enforce_tmx).and_return(true)
    ServiceProvider.find_by(issuer: service_provider_issuer(sp)).
        update(in_person_proofing_enabled: true)
  end

  before(:each) do
    complete_entire_ipp_flow(user, tmx_status)
  end

  context 'ThreatMetrix determination of Review' do
    let(:tmx_status) { 'Review' }

    context 'User passes IPP and passes TMX Review' do
      it 'initially shows the user the barcode page', allow_browser_log: true do
        expect_in_person_step_indicator_current_step(
            t('step_indicator.flows.idv.go_to_the_post_office'),
            )
        expect(page).to have_content(t('in_person_proofing.headings.barcode').tr(' ', ' '))
        expect(page).to have_content(Idv::InPerson::EnrollmentCodeFormatter.format(enrollment_code))
        expect(page).to have_current_path(idv_in_person_ready_to_verify_path)
      end

      it 'shows the user the Please Call screen after passing IPP', allow_browser_log: true do
        Capybara.reset_session!
        sign_in_live_with_2fa(user)
        expect(page).to have_current_path(account_path)
        visit_idp_from_sp_with_ial2(sp)
        expect(page).to have_current_path(idv_in_person_ready_to_verify_path)

        enrollment = InPersonEnrollment.last
        profile = enrollment.profile
        
        # set fraud review to pending: 
        profile.deactivate_for_fraud_review
        # pass the enrollment:
        enrollment.update(status: 'passed')
        
        profile.reload
        enrollment.reload
        expect(page).to have_current_path(idv_in_person_ready_to_verify_path)
        page.refresh
        expect(page).to have_current_path(idv_please_call_path)
      end

      it 'does not allow the user to restart the IPP flow', allow_browser_log: true do
        enrollment = InPersonEnrollment.last
        profile = enrollment.profile
        
        # set fraud review to pending: 
        profile.deactivate_for_fraud_review
        # pass the enrollment:
        enrollment.update(status: 'passed')
        
        profile.reload
        enrollment.reload

        visit_idp_from_sp_with_ial2(sp)
        expect(page).to have_current_path(idv_please_call_path)
        page.visit('/verify/welcome')
        expect(page).to have_current_path(idv_please_call_path)
        page.visit('/verify/in_person/document_capture')
        expect(page).to have_current_path(idv_please_call_path)
      end

      it 'shows the user the successful verification screen after passing TMX review', allow_browser_log: true do
        enrollment = InPersonEnrollment.last
        profile = enrollment.profile
        
        # set fraud review to pending: 
        profile.deactivate_for_fraud_review
        # pass the enrollment:
        enrollment.update(status: 'passed')
        
        profile.reload
        enrollment.reload

        visit_idp_from_sp_with_ial2(sp)
        expect(page).to have_current_path(idv_please_call_path)

        mark_in_person_enrollment_passed(user)
        page.visit('/verify/welcome')
        expect(page).to have_current_path(idv_activated_path)
      end
    end

    context 'User fails IPP and deactivates for TMX review' do
      it 'initially shows the user the barcode page', allow_browser_log: true do
        expect_in_person_step_indicator_current_step(
            t('step_indicator.flows.idv.go_to_the_post_office'),
            )
        expect(page).to have_content(t('in_person_proofing.headings.barcode').tr(' ', ' '))
        expect(page).to have_content(Idv::InPerson::EnrollmentCodeFormatter.format(enrollment_code))
        expect(page).to have_current_path(idv_in_person_ready_to_verify_path)
      end 

      it 'allows the user to restart the flow', allow_browser_log: true do
        enrollment = InPersonEnrollment.last
        profile = enrollment.profile
        # set fraud review to pending: 
        profile.deactivate_for_fraud_review
        # fail at post office
        enrollment.update(
          status: :failed,
          proofed_at: Time.zone.now,
          status_check_completed_at: Time.zone.now
        )

        profile.reload
        enrollment.reload

        visit_idp_from_sp_with_ial2(sp)
        expect(page).not_to have_current_path(idv_please_call_path)
        # redo the flow:
        complete_entire_ipp_flow(user, tmx_status)
        expect(page).to have_current_path(idv_in_person_ready_to_verify_path)
      end 
    end
  end

  context 'ThreatMetrix determination of Reject' do
    let(:tmx_status) { 'Reject' }

    context 'User passes IPP and rejects for TMX review' do
      it 'initially shows the user the barcode page', allow_browser_log: true do
        expect_in_person_step_indicator_current_step(
            t('step_indicator.flows.idv.go_to_the_post_office'),
            )
        expect(page).to have_content(t('in_person_proofing.headings.barcode').tr(' ', ' '))
        expect(page).to have_content(Idv::InPerson::EnrollmentCodeFormatter.format(enrollment_code))
        expect(page).to have_current_path(idv_in_person_ready_to_verify_path)
      end

      it 'shows the user the Please Call screen after passing IPP', allow_browser_log: true do
        Capybara.reset_session!
        sign_in_live_with_2fa(user)
        expect(page).to have_current_path(account_path)
        visit_idp_from_sp_with_ial2(sp)
        expect(page).to have_current_path(idv_in_person_ready_to_verify_path)

        enrollment = InPersonEnrollment.last
        profile = enrollment.profile
        
        # set fraud review to pending: 
        profile.deactivate_for_fraud_review
        # pass the enrollment:
        enrollment.update(status: 'passed')
        
        profile.reload
        enrollment.reload
        expect(page).to have_current_path(idv_in_person_ready_to_verify_path)
        page.refresh
        expect(page).to have_current_path(idv_please_call_path)

        # reject the user
        profile.reject_for_fraud(notify_user: false)
        page.refresh
        expect(page).to have_current_path(idv_not_verified_path)
      end

      it 'does not allow the user to restart the IPP flow', allow_browser_log: true do
        enrollment = InPersonEnrollment.last
        profile = enrollment.profile
        
        # set fraud review to pending: 
        profile.deactivate_for_fraud_review
        # pass the enrollment:
        enrollment.update(status: 'passed')
        
        profile.reload
        enrollment.reload

         # reject the user
         profile.reject_for_fraud(notify_user: false)

        visit_idp_from_sp_with_ial2(sp)
        expect(page).to have_current_path(idv_not_verified_path)
        page.visit('/verify/welcome')
        expect(page).to have_current_path(idv_not_verified_path)
        page.visit('/verify/in_person/document_capture')
        expect(page).to have_current_path(idv_not_verified_path)
      end
    end
  end
end