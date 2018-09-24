class DocAuth < ApplicationRecord
  belongs_to :user, inverse_of: :doc_auth
  validates :user_id, presence: true
end
