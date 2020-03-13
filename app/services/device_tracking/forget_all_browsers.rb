module DeviceTracking
  class ForgetAllBrowsers
    attr_reader :user, :remember_device_revoked_at

    def initialize(user, remember_device_revoked_at: Time.zone.now)
      @user = user
      @remember_device_revoked_at = remember_device_revoked_at
    end

    def call
      UpdateUser.new(
        user: user,
        attributes: {
          remember_device_revoked_at: remember_device_revoked_at,
        },
      ).call
    end
  end
end
