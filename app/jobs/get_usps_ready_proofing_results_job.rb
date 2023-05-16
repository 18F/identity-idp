class GetUspsReadyProofingResultsJob < GetUspsProofingResultsJob
  MILLISECONDS_PER_SECOND = 1000.0 # Specify float value to use floating point math

  queue_as :long_running

  def perform(_now)
    return true unless IdentityConfig.store.in_person_proofing_enabled
    puts "PERFORM CALLED IN PROOFING RESULTS JOB"

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
    enrollments = InPersonEnrollment.ready_for_usps_status_check(
      ...reprocess_delay_minutes.minutes.ago,
    )

    started_at = Time.zone.now
    analytics.idv_in_person_usps_ready_proofing_results_job_started(
      enrollments_count: enrollments.count,
      reprocess_delay_minutes: reprocess_delay_minutes,
    )

    check_enrollments(enrollments)

    percent_enrollments_errored = 0
    if enrollment_outcomes[:enrollments_checked] > 0
      percent_enrollments_errored =
        (enrollment_outcomes[:enrollments_errored].fdiv(
          enrollment_outcomes[:enrollments_checked],
        ) * 100).round(2)
    end

    analytics.idv_in_person_usps_ready_proofing_results_job_completed(
      **enrollment_outcomes,
      duration_seconds: (Time.zone.now - started_at).seconds.round(2),
      # Calculate % of errored enrollments
      percent_enrollments_errored:,
    )

    true

  end
end
