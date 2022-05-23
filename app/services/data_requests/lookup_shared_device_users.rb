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
    attr_reader :initial_users, :depth

    def initialize(initial_users, depth = 3)
      @initial_users = initial_users
      @depth = depth
      @user_ids = initial_users.map(&:id).to_set
      @device_cookie_uuids = Set.new
    end

    def call
      depth.times do |i|
        warn "Searching at depth #{i}"
        self.device_cookie_uuids += Device.where(user_id: user_ids).pluck(:cookie_uuid)
        self.user_ids += Device.where(cookie_uuid: device_cookie_uuids).pluck(:user_id)
      end
      User.where(id: user_ids).all
    end

    private

    attr_accessor :user_ids, :device_cookie_uuids
  end
end
