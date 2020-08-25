module DocAuth
  module Acuant
    module ResultCodes
      ResultCode = Struct.new(:code, :name, :billed) do
        alias_method :billed?, :billed
      end

      # The authentication test results are unknown. We are not billed for these
      UNKNOWN = ResultCode.new(0, 'Unknown', false).freeze
      # The authentication test passed.
      PASSED = ResultCode.new(1, 'Passed', true).freeze
      # The authentication test failed.
      FAILED = ResultCode.new(2, 'Failed', true).freeze
      # The authentication test was skipped (was not run).
      SKIPPED = ResultCode.new(3, 'Skipped', true).freeze
      # The authentication test was inconclusive and further investigation is warranted.
      CAUTION = ResultCode.new(4, 'Caution', true).freeze
      # The authentication test results requires user attention.
      ATTENTION = ResultCode.new(5, 'Attention', true).freeze

      ALL = [
        UNKNOWN,
        PASSED,
        FAILED,
        SKIPPED,
        CAUTION,
        ATTENTION,
      ].freeze

      BY_CODE = ALL.index_by(&:code).freeze

      # @return [ResultCode]
      def self.from_int(code)
        BY_CODE[code]
      end
    end
  end
end
