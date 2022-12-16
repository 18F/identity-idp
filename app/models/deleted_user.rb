class DeletedUser < ApplicationRecord
  def self.create_from_user(user)
    return unless user

    ActiveRecord::Base.transaction(requires_new: true) do
      create!(
        user_id: user.id,
        uuid: user.uuid,
        user_created_at: user.created_at,
        deleted_at: Time.zone.now,
      )
    rescue ActiveRecord::RecordNotUnique
      raise ActiveRecord::Rollback
    end

    nil
  end
end
