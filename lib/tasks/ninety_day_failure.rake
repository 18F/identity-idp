namespace :report do
  task failure_rate: :environment do
    require 'reporting/identity_verification_report'

    start_at = 90.days.ago.beginning_of_day

    puts 'date,welcome_visited,images_uploaded,workflow_complete,blanket_completion,actual_completion'

    while start_at < (Time.zone.now - 1.day)
      report = Reporting::IdentityVerificationReport.new(
        issuer: nil,
        time_range: start_at.beginning_of_day..(start_at + 1.day).end_of_day,
        progress: false,
      )
      welcome_visited = report.idv_started
      images_uploaded = report.idv_doc_auth_image_vendor_submitted
      workflow_complete = report.idv_final_resolution
      blanket_completion = workflow_complete.to_f / welcome_visited.to_f * 100
      actual_completion = workflow_complete.to_f / images_uploaded.to_f * 100
      warn "#{start_at.to_date},#{welcome_visited},#{images_uploaded},#{workflow_complete},#{blanket_completion},#{actual_completion}"


      start_at += 1.day
    end
    # warn report.to_csv
  end
end
