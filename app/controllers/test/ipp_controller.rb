# frozen_string_literal: true

module Test
  class IppController < ApplicationController
    layout 'no_card'

    before_action :render_not_found_in_production

    def index
      @enrollments = InPersonEnrollment
        .order(created_at: :desc)
        .limit(10)

      @enrollments_with_actions = @enrollments.map do |e|
        case e.status
        when 'pending' then [e, :approve]
        else [e]
        end
      end
    end

    def update
      enrollment_id = params['enrollment'].to_i
      enrollment = InPersonEnrollment.find(enrollment_id)

      if enrollment.present?
        approve_enrollment(enrollment)
      end

      redirect_to test_ipp_url
    end

    private

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

    def render_not_found_in_production
      return unless Rails.env.production?
      render_not_found
    end
  end
end
