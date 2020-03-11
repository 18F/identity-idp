module Users
  class ForgetAllDevicesController < ApplicationController
    before_action :authenticate_user!
    before_action :confirm_two_factor_authenticated

    def show
      analytics.track_event(Analytics::FORGET_ALL_DEVICES_VISITED)
    end

    def destroy
      DeviceTracking::ForgetAllDevices.new(current_user).call

      analytics.track_event(Analytics::FORGET_ALL_DEVICES_SUBMITTED)

      redirect_to account_path
    end
  end
end
