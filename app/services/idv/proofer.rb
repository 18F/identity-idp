module Idv
  module Proofer
    ATTRIBUTES = %i[
      uuid
      first_name last_name middle_name gen
      address1 address2 city state zipcode
      prev_address1 prev_address2 prev_city prev_state prev_zipcode
      ssn dob phone email
      ccn mortgage home_equity_line auto_loan
      bank_account bank_account_type bank_routing
      state_id_number state_id_type state_id_jurisdiction
    ].freeze

    STAGES = %i[resolution state_id address].freeze

    @vendors = {}

    class << self
      attr_accessor :configuration

      def configure
        self.configuration ||= Configuration.new
        yield(configuration)
      end

      class Configuration
        attr_accessor :mock_fallback, :raise_on_missing_proofers
        def initialize
          @mock_fallback = true
          @raise_on_missing_proofers = true
        end
      end

      def attribute?(key)
        ATTRIBUTES.include?(key&.to_sym)
      end

      def get_vendor(stage)
        @vendors[stage]
      end

      def load_vendors!
        external_vendors = ::Proofer::Base.subclasses
        require_mock_vendors if configuration.mock_fallback
        mock_vendors = ::Proofer::Base.subclasses - external_vendors

        STAGES.each do |stage|
          vendor = find_vendor(stage, external_vendors) || find_vendor(stage, mock_vendors)
          @vendors[stage] = vendor if vendor
        end

        validate_vendors! if configuration.raise_on_missing_proofers
      end

      private

      def require_mock_vendors
        Dir[Rails.root.join('lib', 'proofer_mocks', '*')].each { |file| require file }
      end

      def find_vendor(stage, vendors)
        vendors.find { |vendor| vendor.supported_stage == stage }
      end

      def validate_vendors!
        missing_stages = STAGES - @vendors.keys
        return unless missing_stages.any?
        raise "No proofer vendor configured for stage(s): #{missing_stages.join(', ')}"
      end
    end
  end
end
