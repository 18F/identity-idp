module DeviceTracking
  class LookupDeviceForUser
    def self.call(user_id, cookie_guid)
      Device.find_by(user_id: user_id, cookie_uuid: cookie_guid)
    end
  end
end
