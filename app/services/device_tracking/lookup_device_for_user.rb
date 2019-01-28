module DeviceTracking
  class LookupDeviceForUser
    def self.call(user, cookie_guid)
      Device.find_by(user_id: user.id, cookie_uuid: cookie_guid)
    end
  end
end
