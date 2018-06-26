class UspsUploadController < ApplicationController
  def create
    authorize do
      UspsUploader.new.run unless HolidayService.observed_holiday?(today)
      render plain: 'ok'
    end
  end

  private

  def authorize
    # Check for empty to make sure that the token is configured
    if authorization_token && authorization_token == Figaro.env.usps_upload_token
      yield
    else
      head :unauthorized
    end
  end

  def authorization_token
    request.headers['X-USPS-UPLOAD-TOKEN']
  end

  def today
    Time.zone.today
  end
end
