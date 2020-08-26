class DocAuthRecord < ApplicationRecord
  self.table_name = 'doc_auths'

  belongs_to :user, inverse_of: :doc_auth
  validates :user_id, presence: true
end
