class DocAuthLog < ApplicationRecord
  belongs_to :user

  # rubocop:disable Rails/InverseOf
  belongs_to :service_provider,
             foreign_key: 'issuer',
             primary_key: 'issuer'
  # rubocop:enable Rails/InverseOf

  def self.verified_users_count
    Profile.where.not(verified_at: nil).count
  end
end
