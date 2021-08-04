class GpoDailyJob < ApplicationJob
  # Enqueue a test letter every day, but only upload letters on working weekdays
  def perform
    GpoDailyTestSender.new.run

    GpoConfirmationUploader.new.run unless CalendarService.weekend_or_holiday?(Time.zone.today)
  end
end
