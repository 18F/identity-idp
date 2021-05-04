class SpReturnLog < ApplicationRecord
  belongs_to :user

  belongs_to :service_provider,
             foreign_key: 'issuer',
             primary_key: 'issuer'
end
