# frozen_string_literal: true

module Idv
  class SsnEditDistanceCalculator
    attr_reader :previous_ssn, :current_ssn

    # @param previous_ssn [String]
    def initialize(previous_ssn, current_ssn)
      @previous_ssn = previous_ssn
      @current_ssn = current_ssn
    end

    def compute
      previous_ssn.chars.zip(current_ssn.chars).reduce(0) do |acc, chars|
        if chars.first == chars.last || chars.last.nil?
          acc
        else
          acc + 1
        end
      end
    end
  end
end
