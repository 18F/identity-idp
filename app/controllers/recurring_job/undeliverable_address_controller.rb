module RecurringJob
  class UndeliverableAddressController < BaseController
    def create
      UndeliverableAddressNotifier.new.call
      render plain: 'ok'
    end

    private

    def config_auth_token
      Figaro.env.usps_download_token
    end
  end
end
