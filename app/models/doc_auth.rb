class DocAuth < ApplicationRecord
  belongs_to :user, inverse_of: :doc_auth
end
