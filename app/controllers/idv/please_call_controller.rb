# frozen_string_literal: true

module Idv
  class PleaseCallController < ApplicationController
    include Idv::AvailabilityConcern
    include FraudReviewConcern

    before_action :confirm_two_factor_authenticated
    before_action :handle_fraud_rejection
    before_action :confirm_fraud_pending

    FRAUD_REVIEW_CONTACT_WITHIN_DAYS = 14.days.freeze

    def show
      analytics.idv_please_call_visited
      pending_at = current_user.fraud_review_pending_profile.fraud_review_pending_at
      @call_by_date = pending_at + FRAUD_REVIEW_CONTACT_WITHIN_DAYS
      @in_person = ipp_enabled_and_enrollment_passed_or_in_fraud_review?
    end

    def ipp_enabled_and_enrollment_passed_or_in_fraud_review?
      return unless in_person_tmx_enabled?
      in_person_proofing_enabled? && (ipp_enrollment_passed? || ipp_enrollment_in_fraud_review?)
    end

    private

    def confirm_fraud_pending
      if !fraud_review_pending?
        redirect_to account_url
      end
    end

    def in_person_proofing_enabled?
      IdentityConfig.store.in_person_proofing_enabled
    end

    def in_person_tmx_enabled?
      IdentityConfig.store.in_person_proofing_enforce_tmx
    end

    # we only want to handle enrollments that have passed
    def ipp_enrollment_passed?
      current_user&.latest_in_person_enrollment_status == 'passed'
    end

    def ipp_enrollment_in_fraud_review?
      current_user&.latest_in_person_enrollment_status == 'in_fraud_review'
    end
  end
end
