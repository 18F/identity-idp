class GpoDailyJob < ApplicationJob
  include GoodJob::ActiveJobExtensions::Concurrency

  good_job_control_concurrency_with(
    enqueue_limit: 1,
    perform_limit: 1,
    key: -> { "gpo-daily-job-#{arguments.first}" },
  )

  # Enqueue a test letter every day, but only upload letters on working weekdays
  def perform(date)
    GpoDailyTestSender.new.run

    GpoConfirmationUploader.new.run unless CalendarService.weekend_or_holiday?(date)
  end
end
