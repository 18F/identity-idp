class DocAuthLog < ApplicationRecord
  belongs_to :user

  # rubocop:disable Rails/InverseOf
  belongs_to :service_provider,
             foreign_key: 'issuer',
             primary_key: 'issuer'
  # rubocop:enable Rails/InverseOf

  self.ignored_columns = [:email_sent_view_at, :email_sent_view_count]
  self.ignored_columns = [:send_link_view_at, :send_link_view_count]
end
