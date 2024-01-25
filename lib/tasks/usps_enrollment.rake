namespace :usps_enrollment do

  desc 'Pass an enrollment'
  task pass: :environment do
    # FIXME: Check if we're in prod, and yell at the user + fail if so!

    enrollment = InPersonEnrollment.find_by_enrollment_code(ENV.fetch('ENROLLMENT_CODE', ''))
    raise "No such enrollment" unless enrollment.present?

    # Do we still need this?
    enrollment.update(unique_id: enrollment.usps_unique_id) if enrollment.unique_id.blank?

    mock_response = {
      # TODO: This should actually be in CST apparently.
      'transactionEndDateTime' => Time.zone.now.strftime('%m/%d/%Y %H%M%S'),
      'fromRakeTask' => 'yes'
    }

    # This is probably the most illegal thing I've ever done.
    job = GetUspsProofingResultsJob.new
    job.instance_variable_set('@enrollment_outcomes', { enrollments_passed: 0 })
    job.send(
      :handle_successful_status_update,
      enrollment,
      mock_response
    )

    # Lastly
    enrollment.update(status_check_attempted_at: Time.zone.now)
    pp enrollment.reload
  end

  desc 'Fail an enrollment'
  task fail_enrollment: :environment do
    # Call handle_failed_status
  end

  desc 'Pass an enrollment, but with fraud suspected!'
  task pass_with_fraud: :environment do
    #
  end

  desc 'Fail an enrollment with fraud suspected'
  task fail_with_fraud: :environment do
    # Add fraudSuspected to our response
    enrollment = InPersonEnrollment.find_by_enrollment_code(ENV.fetch('ENROLLMENT_CODE', ''))
    raise "No such enrollment" unless enrollment.present?

    # cargo culting this in
    enrollment.update(unique_id: enrollment.usps_unique_id) if enrollment.unique_id.blank?

    mock_response = {
      # TODO: This should actually be in CST apparently.
      'transactionEndDateTime' => Time.zone.now.strftime('%m/%d/%Y %H%M%S'),
      'fromRakeTask' => 'yes',
      'fraudSuspected' => 'yes',
    }

    job = GetUspsProofingResultsJob.new
    job.instance_variable_set('@enrollment_outcomes', { enrollments_failed: 0 })
    job.send(
      :handle_failed_status,
      enrollment,
      mock_response
    )

    enrollment.update(status_check_attempted_at: Time.zone.now)
    pp enrollment.reload
  end

end