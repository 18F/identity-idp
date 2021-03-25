module RecurringJob
  class GpoUploadController < AuthTokenController
    def create
      today = Time.zone.today
      GpoConfirmationUploader.new.run unless CalendarService.weekend_or_holiday?(today)
      render plain: 'ok'
    end

    private

    def config_auth_token
      AppConfig.env.usps_upload_token
    end
  end
end
