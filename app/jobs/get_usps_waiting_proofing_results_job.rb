class GetUspsWaitingProofingResultsJob < GetUspsProofingResultsJob
  queue_as :long_running

  def perform(_now)
    return true unless ipp_enabled? && ipp_ready_job_enabled?

    @enrollment_outcomes = {
      enrollments_checked: 0,
      enrollments_errored: 0,
      enrollments_expired: 0,
      enrollments_failed: 0,
      enrollments_in_progress: 0,
      enrollments_passed: 0,
    }

    reprocess_delay_minutes = IdentityConfig.store.
      get_usps_proofing_results_job_reprocess_delay_minutes
    enrollments = InPersonEnrollment.needs_status_check_on_waiting_enrollments(
      ...reprocess_delay_minutes.minutes.ago,
    )

    started_at = Time.zone.now
    analytics.idv_in_person_usps_proofing_results_job_started(
      enrollments_count: enrollments.count,
      reprocess_delay_minutes: reprocess_delay_minutes,
      job_name: self.class.name,
    )

    check_enrollments(enrollments)

    analytics.idv_in_person_usps_proofing_results_job_completed(
      **enrollment_outcomes,
      duration_seconds: (Time.zone.now - started_at).seconds.round(2),
      percent_enrollments_errored: percent_errored,
      job_name: self.class.name,
    )

    true
  end
end
