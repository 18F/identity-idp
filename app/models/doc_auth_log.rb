# frozen_string_literal: true

class DocAuthLog < ApplicationRecord
  belongs_to :user

  # rubocop:disable Rails/InverseOf
  belongs_to :service_provider,
             foreign_key: 'issuer',
             primary_key: 'issuer'
  # rubocop:enable Rails/InverseOf

  # rubocop:disable Rails/UnusedIgnoredColumns
  self.ignored_columns = [
    :email_sent_view_at,
    :email_sent_view_count,
    :send_link_view_at,
    :send_link_view_count,
  ]
  # rubocop:enable Rails/UnusedIgnoredColumns
end
