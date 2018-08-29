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

    @vendors = nil

    class << self
      def attribute?(key)
        ATTRIBUTES.include?(key&.to_sym)
      end

      def get_vendor(stage)
        stage = stage.to_sym
        vendor = vendors[stage]
        return vendor if vendor.present?
        return unless mock_fallback_enabled?
        mock_vendors[stage]
      end

      def validate_vendors!
        return if mock_fallback_enabled?
        missing_stages = STAGES - vendors.keys
        return if missing_stages.empty?
        raise "No proofer vendor configured for stage(s): #{missing_stages.join(', ')}"
      end

      private

      def vendors
        @vendors ||= begin
          require_mock_vendors_if_enabled
          available_vendors.each_with_object({}) do |vendor, result|
            vendor_stage = vendor.stage&.downcase&.to_sym
            next unless STAGES.include?(vendor_stage)
            result[vendor_stage] = vendor
          end
        end
      end

      def available_vendors
        external_vendors = ::Proofer::Base.descendants - mock_vendors.values
        external_vendors.select do |vendor|
          configured_vendor_names.include?(vendor.vendor_name)
        end
      end

      def configured_vendor_names
        JSON.parse(Figaro.env.proofer_vendors || '[]')
      end

      def mock_vendors
        return {} unless mock_fallback_enabled?
        {
          resolution: ResolutionMock,
          state_id: StateIdMock,
          address: AddressMock,
        }
      end

      def require_mock_vendors_if_enabled
        return unless mock_fallback_enabled?
        Dir[Rails.root.join('lib', 'proofer_mocks', '*')].each { |file| require file }
      end

      def mock_fallback_enabled?
        Figaro.env.proofer_mock_fallback == 'true'
      end
    end
  end
end
