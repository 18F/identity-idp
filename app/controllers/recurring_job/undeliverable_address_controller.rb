module RecurringJob
  class UndeliverableAddressController < AuthTokenController
    def create
      UndeliverableAddressNotifier.new.call
      render plain: 'ok'
    end

    private

    def config_auth_token
      Identity::Hostdata.settings.usps_download_token
    end
  end
end
