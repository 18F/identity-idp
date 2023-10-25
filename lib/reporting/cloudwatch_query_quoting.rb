# frozen_string_literal: true

module Reporting
  module CloudwatchQueryQuoting
    # Quotes a string or array to be used as a literal
    # @param [String,Array<String>] str_or_ary
    def quote(str_or_ary)
      if str_or_ary.is_a?(Array)
        '[' + str_or_ary.map { |str| quote(str) }.join(',') + ']'
      else
        %("#{str_or_ary.gsub('"', '\"')}")
      end
    end

    alias_method :q, :quote
  end
end
