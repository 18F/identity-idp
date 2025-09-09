# frozen_string_literal: true

module Test
  class IppController < ApplicationController
    layout 'no_card'

    before_action :authorize
    before_action :confirm_two_factor_authenticated

    def index
      @enrollments = all_enrollments

      @enrollments_with_actions = @enrollments.map do |e|
        case e.status
        when 'pending' then [e, :approve]
        else [e]
        end
      end
    end

    def update
      enrollment = enrollment_for_id

      if enrollment.present?
        approve_enrollment(enrollment)
      else
        flash[:error] = "Could not find pending IPP enrollment with ID #{enrollment_id}"
      end

      redirect_to test_ipp_url
    end

    private

    def all_enrollments
      InPersonEnrollment
        .includes(:user)
        .order(created_at: :desc)
        .limit(10)
    end

    def enrollment_for_id
      InPersonEnrollment.find_by(id: enrollment_id)
    end

    def enrollment_id
      params['enrollment'].to_i
    end

    def approve_enrollment(enrollment)
      return if !enrollment.pending?

      res = JSON.parse(
        UspsInPersonProofing::Mock::Fixtures.request_passed_proofing_results_response,
      )

      job = GetUspsProofingResultsJob.new
      job.instance_variable_set(
        :@enrollment_outcomes,
        { enrollments_passed: 0,
          enrollments_failed: 0,
          enrollments_errored: 0,
          enrollments_expired: 0,
          enrollments_checked: 0 },
      )

      job.send(:process_enrollment_response, enrollment, res)
    end

    def authorize
      return if Rails.env.development?

      render_not_found
    end
  end
end
