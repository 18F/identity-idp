# frozen_string_literal: true

class GetUspsReadyProofingResultsJob < GetUspsProofingResultsJob
  private

  def job_can_run?
    ipp_enabled? && ipp_ready_job_enabled?
  end

  def pending_enrollments
    @pending_enrollments ||= InPersonEnrollment.needs_status_check_on_ready_enrollments(
      ...reprocess_delay_minutes.minutes.ago,
    )
  end
end
