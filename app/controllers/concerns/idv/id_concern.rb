# frozen_string_literal: true

module Idv
  module IdConcern
    extend ActiveSupport::Concern

    private

    def parse_date(date)
      return nil unless date.present?

      if date.instance_of?(String)
        Date.parse(date)
      elsif date.instance_of?(Hash)
        # extract_date_param returns nil for an empty/incomplete date hash.
        formatted = MemorableDateComponent.extract_date_param(date)
        Date.parse(formatted) if formatted
      end
    rescue Date::Error
      # Catch date parsing errors
    end
  end
end
