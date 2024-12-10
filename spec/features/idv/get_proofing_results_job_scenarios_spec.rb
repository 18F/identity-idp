require 'rails_helper'
require 'axe-rspec'

RSpec.feature 'GetUspsProofingResultsJob Scenarios', js: true, allowed_extra_analytics: [:*] do
  include OidcAuthHelper
  include UspsIppHelper
  include ActiveJob::TestHelper

  background do
    allow(IdentityConfig.store).to receive(:in_person_proofing_enabled).and_return(true)
    allow(IdentityConfig.store).to receive(:usps_mock_fallback).and_return(false)
    allow(IdentityConfig.store).to receive(:in_person_proofing_enforce_tmx).and_return(true)
    stub_request_token
    ActiveJob::Base.queue_adapter = :test
  end

  feature 'before/after password reset:' do
    background do
      @user = create(:user, :with_phone, :with_pending_in_person_enrollment)
      @new_password = '$alty pickles'
    end

    scenario 'User resets password and logs in before USPS proofing "passed"' do
      # Given the user has an InPersonEnrollment with status "pending"
      expect(@user.in_person_enrollments.first).to have_attributes(
        status: 'pending',
      )
      # And the user has a Profile that is deactivated pending in person verification
      expect(@user.in_person_enrollments.first.profile).to have_attributes(
        active: false,
        deactivation_reason: nil,
        in_person_verification_pending_at: be_kind_of(Time),
      )

      # When the user resets their password
      reset_password(@user, @new_password)

      # Then the user has an InPersonEnrollment with status "pending"
      expect(@user.in_person_enrollments.first).to have_attributes(
        status: 'pending',
      )
      # And the user has a Profile that is deactivated pending in person verification
      expect(@user.in_person_enrollments.first.profile).to have_attributes(
        active: false,
        deactivation_reason: nil,
        in_person_verification_pending_at: be_kind_of(Time),
      )

      # When the user logs in
      login(@user, @new_password)

      # Then the user is taken to the /verify/welcome page
      expect(current_path).to eq(idv_welcome_path)
      # And the user has an InPersonEnrollment with status "cancelled"
      expect(@user.in_person_enrollments.first).to have_attributes(
        status: 'cancelled',
      )
      # And the user has a Profile that is deactivated with reason "encryption_error"
      expect(@user.in_person_enrollments.first.profile).to have_attributes(
        active: false,
        deactivation_reason: 'encryption_error',
        in_person_verification_pending_at: be_kind_of(Time),
      )

      # When the user logs out
      logout(@user)
      # And the user visits USPS to complete their enrollment
      # And USPS enrollment "passed"
      stub_request_passed_proofing_results
      # And GetUspsProofingResultsJob is performed
      perform_get_usps_proofing_results_job(@user)

      # Then the user has an InPersonEnrollment with status "cancelled"
      expect(@user.in_person_enrollments.first).to have_attributes(
        status: 'cancelled',
      )
      # And the user has a Profile that is deactivated with reason "encryption_error"
      expect(@user.in_person_enrollments.first.profile).to have_attributes(
        active: false,
        deactivation_reason: 'encryption_error',
        in_person_verification_pending_at: be_kind_of(Time),
      )

      # When the user logs in
      login(@user, @new_password)

      # Then the user is taken to the /verify/welcome page
      expect(current_path).to eq(idv_welcome_path)
      # And the user has an InPersonEnrollment with status "cancelled"
      expect(@user.in_person_enrollments.first).to have_attributes(
        status: 'cancelled',
      )
      # And the user has a Profile that is deactivated with reason "encryption_error"
      expect(@user.in_person_enrollments.first.profile).to have_attributes(
        active: false,
        deactivation_reason: 'encryption_error',
        in_person_verification_pending_at: be_kind_of(Time),
      )
    end

    ['failed', 'cancelled', 'expired'].each do |status|
      scenario "User resets password and logs in before USPS proofing \"#{status}\"" do
        # Given the user has an InPersonEnrollment with status "pending"
        expect(@user.in_person_enrollments.first).to have_attributes(
          status: 'pending',
        )
        # And the user has a Profile that is deactivated pending in person verification
        expect(@user.in_person_enrollments.first.profile).to have_attributes(
          active: false,
          deactivation_reason: nil,
          in_person_verification_pending_at: be_kind_of(Time),
        )

        # When the user resets their password
        reset_password(@user, @new_password)

        # Then the user has an InPersonEnrollment with status "pending"
        expect(@user.in_person_enrollments.first).to have_attributes(
          status: 'pending',
        )
        # And the user has a deactivated profile due to in person verification
        expect(@user.in_person_enrollments.first.profile).to have_attributes(
          active: false,
          deactivation_reason: nil,
          in_person_verification_pending_at: be_kind_of(Time),
        )

        # When the user logs in
        login(@user, @new_password)

        # Then the user is taken to the /verify/welcome page
        expect(current_path).to eq(idv_welcome_path)
        # And the user has an InPersonEnrollment with status "cancelled"
        expect(@user.in_person_enrollments.first).to have_attributes(
          status: 'cancelled',
        )
        # And the user has a Profile that is deactivated with reason "encryption_error"
        expect(@user.in_person_enrollments.first.profile).to have_attributes(
          active: false,
          deactivation_reason: 'encryption_error',
          in_person_verification_pending_at: be_kind_of(Time),
        )

        # When the user logs out
        logout(@user)
        # And the user visits USPS to complete their enrollment
        # And USPS enrollment "failed|cancelled|expired"
        stub_request_proofing_results(status, @user.in_person_enrollments.first.enrollment_code)
        # And GetUspsProofingResultsJob is performed
        perform_get_usps_proofing_results_job(@user)

        # Then the user has an InPersonEnrollment with status "cancelled"
        expect(@user.in_person_enrollments.first).to have_attributes(
          status: 'cancelled',
        )
        # And the user has a Profile that is deactivated with reason "encryption_error"
        expect(@user.in_person_enrollments.first.profile).to have_attributes(
          active: false,
          deactivation_reason: 'encryption_error',
          in_person_verification_pending_at: be_kind_of(Time),
        )

        # When the user logs in
        login(@user, @new_password)

        # Then the user is taken to the /verify/welcome page
        expect(current_path).to eq(idv_welcome_path)
        # And the user has an InPersonEnrollment with status "cancelled"
        expect(@user.in_person_enrollments.first).to have_attributes(
          status: 'cancelled',
        )
        # And the user has a Profile that is deactivated with reason "encryption_error"
        expect(@user.in_person_enrollments.first.profile).to have_attributes(
          active: false,
          deactivation_reason: 'encryption_error',
          in_person_verification_pending_at: be_kind_of(Time),
        )
      end
    end

    scenario 'User resets password without logging in before USPS proofing "passed"' do
      # Given the user has an InPersonEnrollment with status "pending"
      expect(@user.in_person_enrollments.first).to have_attributes(
        status: 'pending',
      )
      # And the user has a Profile that is deactivated pending in person verification
      expect(@user.in_person_enrollments.first.profile).to have_attributes(
        active: false,
        deactivation_reason: nil,
        in_person_verification_pending_at: be_kind_of(Time),
      )

      # When the user resets their password
      reset_password(@user, @new_password)

      # Then the user has an InPersonEnrollment with status "pending"
      expect(@user.in_person_enrollments.first).to have_attributes(
        status: 'pending',
      )
      # And the user has a deactivated profile due to in person verification
      expect(@user.in_person_enrollments.first.profile).to have_attributes(
        active: false,
        deactivation_reason: nil,
        in_person_verification_pending_at: be_kind_of(Time),
      )

      # And the user visits USPS to complete their enrollment
      # And USPS enrollment "passed"
      stub_request_passed_proofing_results
      # And GetUspsProofingResultsJob is performed
      perform_get_usps_proofing_results_job(@user)

      # Then the user has an InPersonEnrollment with status "passed"
      expect(@user.in_person_enrollments.first).to have_attributes(
        status: 'passed',
      )
      # And the user has a Profile that is active
      expect(@user.in_person_enrollments.first.profile).to have_attributes(
        active: true,
        deactivation_reason: nil,
        in_person_verification_pending_at: nil,
      )

      # When the user logs in
      login(@user, @new_password)

      # Then the user is taken to the /verify/welcome page
      expect(current_path).to eq(idv_welcome_path)
      # And the user has an InPersonEnrollment with status "passed"
      expect(@user.in_person_enrollments.first).to have_attributes(
        status: 'passed',
      )
      # And the user has a Profile that is deactivated with reason "encryption_error"
      expect(@user.in_person_enrollments.first.profile).to have_attributes(
        active: false,
        deactivation_reason: 'encryption_error',
        in_person_verification_pending_at: nil,
      )
    end

    ['failed', 'cancelled', 'expired'].each do |status|
      scenario "User resets password without logging in before USPS proofing \"#{status}\"" do
        # Given the user has an InPersonEnrollment with status "pending"
        expect(@user.in_person_enrollments.first).to have_attributes(
          status: 'pending',
        )
        # And the user has a Profile that is deactivated pending in person verification
        expect(@user.in_person_enrollments.first.profile).to have_attributes(
          active: false,
          deactivation_reason: nil,
          in_person_verification_pending_at: be_kind_of(Time),
        )

        # When the user resets their password
        reset_password(@user, @new_password)

        # Then the user has an InPersonEnrollment with status "pending"
        expect(@user.in_person_enrollments.first).to have_attributes(
          status: 'pending',
        )
        # And the user has a Profile that is deactivated pending in person verification
        expect(@user.in_person_enrollments.first.profile).to have_attributes(
          active: false,
          deactivation_reason: nil,
          in_person_verification_pending_at: be_kind_of(Time),
        )

        # And the user visits USPS to complete their enrollment
        # And USPS enrollment "failed|cancelled|expired"
        stub_request_proofing_results(status, @user.in_person_enrollments.first.enrollment_code)
        # And GetUspsProofingResultsJob is performed
        perform_get_usps_proofing_results_job(@user)

        # Then the user has an InPersonEnrollment with status "failed|cancelled|expired"
        expect(@user.in_person_enrollments.first).to have_attributes(
          status: status,
        )
        # And the user has a Profile that is deactivated with reason "verification_cancelled"
        expect(@user.in_person_enrollments.first.profile).to have_attributes(
          active: false,
          deactivation_reason: 'verification_cancelled',
          in_person_verification_pending_at: nil,
        )

        # When the user logs in
        login(@user, @new_password)

        # Then the user is taken to the /verify/welcome page
        expect(current_path).to eq(idv_welcome_path)
        # And the user has an InPersonEnrollment with status "failed|cancelled|expired"
        expect(@user.in_person_enrollments.first).to have_attributes(
          status: status,
        )
        # And the user has a Profile that is deactivated with reason "verification_cancelled"
        expect(@user.in_person_enrollments.first.profile).to have_attributes(
          active: false,
          deactivation_reason: 'verification_cancelled',
          in_person_verification_pending_at: nil,
        )
      end
    end

    scenario 'User resets password with personal key after USPS proofing "passed"' do
      # Given the user has an InPersonEnrollment with status "pending"
      expect(@user.in_person_enrollments.first).to have_attributes(
        status: 'pending',
      )
      # And the user has a Profile that is deactivated pending in person verification
      expect(@user.in_person_enrollments.first.profile).to have_attributes(
        active: false,
        deactivation_reason: nil,
        in_person_verification_pending_at: be_kind_of(Time),
      )

      # When the user visits USPS to complete their enrollment
      # And USPS enrollment "passed"
      stub_request_passed_proofing_results
      # And GetUspsProofingResultsJob is performed
      perform_get_usps_proofing_results_job(@user)

      # Then the user has an InPersonEnrollment with status "passed"
      expect(@user.in_person_enrollments.first).to have_attributes(
        status: 'passed',
      )
      # And the user has a Profile that is active
      expect(@user.in_person_enrollments.first.profile).to have_attributes(
        active: true,
        deactivation_reason: nil,
        in_person_verification_pending_at: nil,
      )

      # When the user resets their password
      reset_password(@user, @new_password)

      # Then the user has an InPersonEnrollment with status "passed"
      expect(@user.in_person_enrollments.first).to have_attributes(
        status: 'passed',
      )
      # And the user has a Profile that is deactivated with reason "password_reset"
      expect(@user.in_person_enrollments.first.profile).to have_attributes(
        active: false,
        deactivation_reason: 'password_reset',
        in_person_verification_pending_at: nil,
      )

      # When the user logs in
      login(@user, @new_password)
      # Then the user is taken to the /account/reactivate/start page
      expect(current_path).to eq(reactivate_account_path)

      # When the user attempts to reactivate account without their personal key
      account_reactivation_with_personal_key(@user, @new_password)

      # Then the user is taken to the /sign_up/completed page
      expect(current_path).to eq(sign_up_completed_path)
      # And the user has an InPersonEnrollment with status "passed"
      expect(@user.in_person_enrollments.first).to have_attributes(
        status: 'passed',
      )
      # And the user has a Profile that is active
      expect(@user.in_person_enrollments.first.profile).to have_attributes(
        active: true,
        deactivation_reason: nil,
        in_person_verification_pending_at: nil,
      )
    end

    scenario 'User resets password without personal key after USPS proofing "passed"' do
      # Given the user has an InPersonEnrollment with status "pending"
      expect(@user.in_person_enrollments.first).to have_attributes(
        status: 'pending',
      )
      # And the user has a Profile that is deactivated pending in person verification
      expect(@user.in_person_enrollments.first.profile).to have_attributes(
        active: false,
        deactivation_reason: nil,
        in_person_verification_pending_at: be_kind_of(Time),
      )

      # When the user visits USPS to complete their enrollment
      # And USPS enrollment "passed"
      stub_request_passed_proofing_results
      # And GetUspsProofingResultsJob is performed
      perform_get_usps_proofing_results_job(@user)

      # Then the user has an InPersonEnrollment with status "passed"
      expect(@user.in_person_enrollments.first).to have_attributes(
        status: 'passed',
      )
      # And the user has a Profile that is active
      expect(@user.in_person_enrollments.first.profile).to have_attributes(
        active: true,
        deactivation_reason: nil,
        in_person_verification_pending_at: nil,
      )

      # When the user resets their password
      reset_password(@user, @new_password)

      # And the user has an InPersonEnrollment with status "passed"
      expect(@user.in_person_enrollments.first).to have_attributes(
        status: 'passed',
      )
      # And the user has a Profile that is deactivated with reason "password_reset"
      expect(@user.in_person_enrollments.first.profile).to have_attributes(
        active: false,
        deactivation_reason: 'password_reset',
        in_person_verification_pending_at: nil,
      )

      # When the user logs in
      login(@user, @new_password)
      # Then the user is taken to the /account/reactivate/start page
      expect(current_path).to eq(reactivate_account_path)

      # When the user attempts to reactivate account without their personal key
      account_reactivation_without_personal_key

      # Then the user is taken to the /verify/welcome page
      expect(current_path).to eq(idv_welcome_path)
      # And the user has an InPersonEnrollment with status "passed"
      expect(@user.in_person_enrollments.first).to have_attributes(
        status: 'passed',
      )
      # And the user has a Profile that is deactivated with reason "password_reset"
      expect(@user.in_person_enrollments.first.profile).to have_attributes(
        active: false,
        deactivation_reason: 'password_reset',
        in_person_verification_pending_at: nil,
      )
    end

    ['failed', 'cancelled', 'expired'].each do |status|
      scenario "User resets password after USPS proofing \"#{status}\"" do
        # Given the user has an InPersonEnrollment with status "pending"
        expect(@user.in_person_enrollments.first).to have_attributes(
          status: 'pending',
        )
        # And the user has a Profile that is deactivated pending in person verification
        expect(@user.in_person_enrollments.first.profile).to have_attributes(
          active: false,
          deactivation_reason: nil,
          in_person_verification_pending_at: be_kind_of(Time),
        )

        # When the user visits USPS to complete their enrollment
        # And USPS enrollment "failed|cancelled|expired"
        stub_request_proofing_results(status, @user.in_person_enrollments.first.enrollment_code)
        # And GetUspsProofingResultsJob is performed
        perform_get_usps_proofing_results_job(@user)

        # Then the user has an InPersonEnrollment with status "failed|cancelled|expired"
        expect(@user.in_person_enrollments.first).to have_attributes(
          status: status,
        )
        # And the user has a Profile that is deactivated with reason "verification_cancelled"
        expect(@user.in_person_enrollments.first.profile).to have_attributes(
          active: false,
          deactivation_reason: 'verification_cancelled',
          in_person_verification_pending_at: nil,
        )

        # When the user resets their password
        reset_password(@user, @new_password)

        # Then the user has an InPersonEnrollment with status "failed|cancelled|expired"
        expect(@user.in_person_enrollments.first).to have_attributes(
          status: status,
        )
        # And the user has a Profile that is deactivated with reason "verification_cancelled"
        expect(@user.in_person_enrollments.first.profile).to have_attributes(
          active: false,
          deactivation_reason: 'verification_cancelled',
          in_person_verification_pending_at: nil,
        )

        # When the user logs in
        login(@user, @new_password)

        # Then the user is taken to the /verify/welcome page
        expect(current_path).to eq(idv_welcome_path)
        # And the user has an InPersonEnrollment with status "failed|cancelled|expired"
        expect(@user.in_person_enrollments.first).to have_attributes(
          status: status,
        )
        # And the user has a Profile that is deactivated with reason "verification_cancelled"
        expect(@user.in_person_enrollments.first.profile).to have_attributes(
          active: false,
          deactivation_reason: 'verification_cancelled',
          in_person_verification_pending_at: nil,
        )
      end
    end

    scenario <<~EOS.squish do
      User resets password and logs in before USPS proofing "passed" with fraud review pending
    EOS
      @user.in_person_enrollments.first.profile.update(
        fraud_review_pending_at: 1.day.ago,
        fraud_pending_reason: 'threatmetrix_review',
        proofing_components: { threatmetrix_review_status: 'review' },
      )

      # Given the user has an InPersonEnrollment with status "pending"
      expect(@user.in_person_enrollments.first).to have_attributes(
        status: 'pending',
      )
      # And the user has a Profile that is deactivated pending in person verification and
      # fraud review
      expect(@user.in_person_enrollments.first.profile).to have_attributes(
        active: false,
        deactivation_reason: nil,
        in_person_verification_pending_at: be_kind_of(Time),
        fraud_pending_reason: 'threatmetrix_review',
        fraud_review_pending_at: be_kind_of(Time),
      )

      # When the user resets their password
      reset_password(@user, @new_password)

      # Then the user has an InPersonEnrollment with status "pending"
      expect(@user.in_person_enrollments.first).to have_attributes(
        status: 'pending',
      )
      # And the user has a Profile that is deactivated pending in person verification and
      # fraud review
      expect(@user.in_person_enrollments.first.profile).to have_attributes(
        active: false,
        deactivation_reason: nil,
        in_person_verification_pending_at: be_kind_of(Time),
        fraud_pending_reason: 'threatmetrix_review',
        fraud_review_pending_at: be_kind_of(Time),
      )

      # When the user logs in
      login(@user, @new_password)

      # Then the user is taken to the /verify/welcome page
      expect(current_path).to eq(idv_welcome_path)
      # And the user has an InPersonEnrollment with status "cancelled"
      expect(@user.in_person_enrollments.first).to have_attributes(
        status: 'cancelled',
      )
      # And the user has a Profile that is deactivated with reason "encryption_error" and
      # pending in person verification and fraud review
      expect(@user.in_person_enrollments.first.profile).to have_attributes(
        active: false,
        deactivation_reason: 'encryption_error',
        in_person_verification_pending_at: be_kind_of(Time),
        fraud_pending_reason: 'threatmetrix_review',
        fraud_review_pending_at: be_kind_of(Time),
      )

      # When the user logs out
      logout(@user)
      # And the user visits USPS to complete their enrollment
      # And USPS enrollment "passed"
      stub_request_passed_proofing_results
      # And GetUspsProofingResultsJob is performed
      perform_get_usps_proofing_results_job(@user)

      # Then the user has an InPersonEnrollment with status "cancelled"
      expect(@user.in_person_enrollments.first).to have_attributes(
        status: 'cancelled',
      )
      # And the user has a Profile that is deactivated with reason "encryption_error" and
      # pending fraud review
      expect(@user.in_person_enrollments.first.profile).to have_attributes(
        active: false,
        deactivation_reason: 'encryption_error',
        in_person_verification_pending_at: be_kind_of(Time),
        fraud_pending_reason: 'threatmetrix_review',
        fraud_review_pending_at: be_kind_of(Time),
      )

      # When the user logs in
      login(@user, @new_password)

      # Then the user is taken to the /verify/welcome page
      expect(current_path).to eq(idv_welcome_path)
      # And the user has an InPersonEnrollment with status "cancelled"
      expect(@user.in_person_enrollments.first).to have_attributes(
        status: 'cancelled',
      )
      # And the user has a Profile that is deactivated with reason "encryption_error" and
      # pending fraud review
      expect(@user.in_person_enrollments.first.profile).to have_attributes(
        active: false,
        deactivation_reason: 'encryption_error',
        in_person_verification_pending_at: be_kind_of(Time),
        fraud_pending_reason: 'threatmetrix_review',
        fraud_review_pending_at: be_kind_of(Time),
      )
    end

    scenario <<~EOS.squish do
      User resets password without logging in before USPS proofing "passed" with fraud review pending
    EOS
      @user.in_person_enrollments.first.profile.update(
        fraud_review_pending_at: 1.day.ago,
        fraud_pending_reason: 'threatmetrix_review',
        proofing_components: { threatmetrix_review_status: 'review' },
      )

      # Given the user has an InPersonEnrollment with status "pending"
      expect(@user.in_person_enrollments.first).to have_attributes(
        status: 'pending',
      )
      # And the user has a Profile that is deactivated pending in person verification and
      # fraud review
      expect(@user.in_person_enrollments.first.profile).to have_attributes(
        active: false,
        deactivation_reason: nil,
        in_person_verification_pending_at: be_kind_of(Time),
        fraud_pending_reason: 'threatmetrix_review',
        fraud_review_pending_at: be_kind_of(Time),
      )

      # When the user resets their password
      reset_password(@user, @new_password)

      # Then the user has an InPersonEnrollment with status "pending"
      expect(@user.in_person_enrollments.first).to have_attributes(
        status: 'pending',
      )
      # And the user has a Profile that is deactivated pending in person verification and
      # fraud review
      expect(@user.in_person_enrollments.first.profile).to have_attributes(
        active: false,
        deactivation_reason: nil,
        in_person_verification_pending_at: be_kind_of(Time),
        fraud_pending_reason: 'threatmetrix_review',
        fraud_review_pending_at: be_kind_of(Time),
      )

      # And the user visits USPS to complete their enrollment
      # And USPS enrollment "passed"
      stub_request_passed_proofing_results
      # And GetUspsProofingResultsJob is performed
      perform_get_usps_proofing_results_job(@user)

      # Then the user has an InPersonEnrollment with status "passed"
      expect(@user.in_person_enrollments.first).to have_attributes(
        status: 'passed',
      )
      # And the user has a Profile that is deactivated pending fraud review
      expect(@user.in_person_enrollments.first.profile).to have_attributes(
        active: false,
        deactivation_reason: nil,
        in_person_verification_pending_at: nil,
        fraud_pending_reason: 'threatmetrix_review',
        fraud_review_pending_at: be_kind_of(Time),
      )

      # When the user logs in
      login(@user, @new_password)

      # Then the user is taken to the /verify/welcome page
      expect(current_path).to eq(idv_welcome_path)
      # And the user has an InPersonEnrollment with status "passed"
      expect(@user.in_person_enrollments.first).to have_attributes(
        status: 'passed',
      )
      # And the user has a Profile that is deactivated with reason "encryption_error" and
      # pending fraud review
      expect(@user.in_person_enrollments.first.profile).to have_attributes(
        active: false,
        deactivation_reason: 'encryption_error',
        in_person_verification_pending_at: nil,
        fraud_pending_reason: 'threatmetrix_review',
        fraud_review_pending_at: be_kind_of(Time),
      )
    end
  end

  def reset_password(user, new_password)
    visit_idp_from_ial2_oidc_sp
    fill_forgot_password_form(user)
    click_reset_password_link_from_email

    fill_in t('forms.passwords.edit.labels.password'), with: new_password
    fill_in t('components.password_confirmation.confirm_label'),
            with: new_password
    fill_in t('components.password_confirmation.confirm_label'),
            with: new_password
    click_on t('forms.passwords.edit.buttons.submit')
    user.reload
  end

  def account_reactivation_without_personal_key
    click_on t('links.account.reactivate.without_key')
    click_on t('forms.buttons.continue')
  end

  def account_reactivation_with_personal_key(user, password)
    personal_key = user.personal_key.gsub(/\W/, '')
    click_on t('links.account.reactivate.with_key')
    fill_in t('forms.personal_key.confirmation_label'), with: personal_key
    click_on t('forms.buttons.continue')
    fill_in t('idv.form.password'), with: password
    click_on t('forms.buttons.continue')
    check t('forms.personal_key.required_checkbox')
    click_on t('forms.buttons.continue')
  end

  def login(user, password)
    user.password = password
    sign_in_live_with_2fa(user)
    user.reload
  end

  def logout(user)
    visit sign_out_url
    user.reload
  end

  def perform_get_usps_proofing_results_job(user)
    perform_enqueued_jobs do
      GetUspsProofingResultsJob.new.perform(Time.zone.now)
    end

    user.reload
  end

  def stub_request_proofing_results(status, enrollment_code)
    case status
    when 'failed'
      stub_request_failed_proofing_results
    when 'cancelled'
      stub_request_unexpected_invalid_enrollment_code(
        { 'responseMessage' => "Enrollment code #{enrollment_code} does not exist" },
      )
    when 'expired'
      stub_request_expired_id_ipp_proofing_results
    else
      throw "Status: #{status} not configured"
    end
  end
end
