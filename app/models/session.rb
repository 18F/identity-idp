class Session < ActiveRecord::Base
  include NonNullUuid

  belongs_to :identity
  validates :session_id, presence: true
end
