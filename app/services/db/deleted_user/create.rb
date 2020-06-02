module Db
  module DeletedUser
    class Create
      def self.call(user_id)
        user = User.find_by(id: user_id)
        return unless user
        ::DeletedUser.create!(user_id: user.id,
                              uuid: user.uuid,
                              user_created_at: user.created_at,
                              deleted_at: Time.zone.now)
      end
    end
  end
end
