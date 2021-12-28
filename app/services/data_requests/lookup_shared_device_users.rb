module DataRequests
  ##
  # This class iteratively looks up networks of users who are sharing devices.
  # It does this by first looking up the devices for a set of users.
  # Then it looks at all of the users who have signed in from those devices.
  # If a user who has not had their devices looked up is present, it looks up
  # the devices for that user.
  # This process is done iteratively until all devices and users within a
  # network are found.
  #
  class LookupSharedDeviceUsers
    attr_reader :initial_users

    def initialize(initial_users)
      @initial_users = initial_users
    end

    def call
      lookup_users(initial_users)
      loop do
        break if user_uuids_to_lookup.empty?
        lookup_users(users_to_lookup)
      end
      user_uuids_by_device
    end

    private

    def lookup_device(device)
      cookie_uuid = device.cookie_uuid
      return if user_uuids_by_device.key?(cookie_uuid)

      warn "Searching for new devices matching #{cookie_uuid}"
      user_ids = Device.where(cookie_uuid: cookie_uuid).pluck(:user_id)
      user_uuids = User.where(id: user_ids).pluck(:uuid)
      user_uuids_by_device[cookie_uuid] = user_uuids
    end

    def lookup_users(users)
      users.each do |user|
        lookup_user(user)
      end
    end

    def lookup_user(user)
      warn "Looking up devices for user: #{user.uuid}"
      devices = user.devices
      devices.each { |device| lookup_device(device) }
      looked_up_user_uuids.add(user.uuid)
    end

    def looked_up_user_uuids
      @looked_up_user_uuids ||= Set.new
    end

    def users_to_lookup
      user_uuids_to_lookup.map do |uuid|
        User.find_by(uuid: uuid)
      end
    end

    ##
    # A hash where the key is a cookie UUID and the values are the UUIDs for the
    # users associated with that device
    #
    def user_uuids_by_device
      @user_uuids_by_device ||= {}
    end

    def user_uuids_to_lookup
      Set.new(user_uuids_by_device.values.flatten) - looked_up_user_uuids
    end
  end
end
