class PushAccountDelete < ApplicationRecord
  validates :created_at, presence: true
  validates :agency_id, presence: true
  validates :uuid, presence: true
end
