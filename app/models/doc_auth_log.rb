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
    :aamva,
  ]
  # rubocop:enable Rails/UnusedIgnoredColumns
end
