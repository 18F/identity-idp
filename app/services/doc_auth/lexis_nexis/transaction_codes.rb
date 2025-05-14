# frozen_string_literal: true

module DocAuth
  module LexisNexis
    module TransactionCodes
      TransactionCode = Struct.new(:code, :name) do
        alias_method :billed?, :billed
      end

      # The authentication test errored (ie: network error)
      ERROR = TransactionCode.new(0, 'error').freeze
      # The authentication test passed.
      PASSED = TransactionCode.new(1, 'passed').freeze
      # The authentication test failed.
      FAILED = TransactionCode.new(2, 'failed').freeze

      ALL = [
        ERROR,
        PASSED,
        FAILED,
      ].freeze

      BY_CODE = ALL.index_by(&:code).freeze

      # @return [TransactionCode]
      def self.from_int(code)
        BY_CODE[code]
      end
    end
  end
end
