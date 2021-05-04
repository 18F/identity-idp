class SpReturnLog < ApplicationRecord
  belongs_to :user

  belongs_to :service_provider,
             inverse_of: :sp_return_logs,
             foreign_key: 'issuer',
             primary_key: 'issuer'
end
