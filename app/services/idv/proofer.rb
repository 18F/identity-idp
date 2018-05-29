module Idv
  module Proofer
    ATTRIBUTES = %i[
      uuid
      first_name last_name middle_name gen
      address1 address2 city state zipcode
      prev_address1 prev_address2 prev_city prev_state prev_zipcode
      ssn dob phone email
      state_id_number state_id_type state_id_jurisdiction
    ].freeze

    STAGES = %i[resolution state_id address].freeze

    @vendors = {}

    class << self
      def attribute?(key)
        ATTRIBUTES.include?(key&.to_sym)
      end

      def init
        @vendors = configure_vendors(STAGES, configuration)
      end

      def get_vendor(stage)
        @vendors[stage]
      end

      def configure
        yield(configuration)
      end

      def configuration
        @configuration ||= Configuration.new
      end

      class Configuration
        attr_accessor :mock_fallback, :raise_on_missing_proofers, :vendors
        def initialize
          @mock_fallback = false
          @raise_on_missing_proofers = true
          @vendors = []
        end
      end

      def configure_vendors(stages, config)
        external_vendors = loaded_vendors
        available_external_vendors = available_vendors(config.vendors, external_vendors)
        require_mock_vendors if config.mock_fallback
        mock_vendors = loaded_vendors - external_vendors

        vendors = assign_vendors(stages, available_external_vendors, mock_vendors)

        validate_vendors(stages, vendors) if config.raise_on_missing_proofers

        vendors
      end

      private

      def loaded_vendors
        ::Proofer::Base.descendants
      end

      def available_vendors(configured_vendors, vendors)
        vendors.select { |vendor| configured_vendors.include?(vendor.vendor_name) }
      end

      def require_mock_vendors
        Dir[Rails.root.join('lib', 'proofer_mocks', '*')].each { |file| require file }
      end

      def assign_vendors(stages, external_vendors, mock_vendors)
        stages.each_with_object({}) do |stage, vendors|
          vendor = stage_vendor(stage, external_vendors) || stage_vendor(stage, mock_vendors)
          vendors[stage] = vendor if vendor
        end
      end

      def stage_vendor(stage, vendors)
        vendors.find { |vendor| stage == vendor.stage&.to_sym }
      end

      def validate_vendors(stages, vendors)
        missing_stages = stages - vendors.keys
        return if missing_stages.empty?
        raise "No proofer vendor configured for stage(s): #{missing_stages.join(', ')}"
      end
    end
  end
end
