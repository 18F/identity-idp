class UspsUploadController < ApplicationController
  def create
    UspsUploader.new.run unless HolidayService.observed_holiday?(today)
    render plain: 'ok'
  end

  private

  def today
    Time.zone.today
  end
end
