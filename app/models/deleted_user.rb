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

# rubocop:disable Layout/LineLength
# == Schema Information
#
# Table name: deleted_users
#
#  id              :bigint           not null, primary key
#  deleted_at      :datetime         not null
#  user_created_at :datetime         not null
#  uuid            :string           not null
#  user_id         :integer          not null
#
# Indexes
#
#  index_deleted_users_on_user_id  (user_id) UNIQUE
#  index_deleted_users_on_uuid     (uuid) UNIQUE
#
# rubocop:enable Layout/LineLength
