class GpoDailyJob < ApplicationJob
  queue_as :low

  # Enqueue a test letter every day, but only upload letters on working weekdays
  def perform(date)
    GpoDailyTestSender.new.run

    GpoConfirmationUploader.new.run unless CalendarService.weekend_or_holiday?(date)
  end
end
