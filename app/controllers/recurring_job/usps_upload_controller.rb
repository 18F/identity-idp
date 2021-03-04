module RecurringJob
  class UspsUploadController < AuthTokenController
    def create
      today = Time.zone.today
      UspsConfirmationUploader.new.run unless CalendarService.weekend_or_holiday?(today)
      render plain: 'ok'
    end

    private

    def config_auth_token
      Identity::Hostdata.settings.usps_upload_token
    end
  end
end
