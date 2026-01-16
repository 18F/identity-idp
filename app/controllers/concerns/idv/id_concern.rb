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
        Date.parse(MemorableDateComponent.extract_date_param(date))
      end
    rescue Date::Error
      # Catch date parsing errors
    end
  end
end
