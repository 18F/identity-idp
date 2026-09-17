# frozen_string_literal: true

module EventSummarizer
  module VendorResultEvaluators
    module Aamva
      ID_TYPES = {
        'state_id_card' => 'non-driving ID card',
        'drivers_license' => "drivers' license",
      }.freeze

      # These mirror Proofing::Aamva::Proofer#successful?, which requires a match on the first list
      # and tolerates 'MISSING' on the second.
      #
      # TODO: Load these from the AAMVA proofer or put them somewhere common
      REQUIRED_VERIFICATION_ATTRIBUTES = %i[
        state_id_number
        dob
        last_name
        first_name
      ].freeze

      REQUIRED_IF_PRESENT_ATTRIBUTES = [:state_id_expiration].freeze

      # errors keys arrive as strings from the Cloudwatch payload.
      REQUIRED_VERIFICATION_ATTRIBUTE_NAMES =
        REQUIRED_VERIFICATION_ATTRIBUTES.map(&:to_s).freeze

      # @param result {Hash} The result structure logged to Cloudwatch
      # @return [Hash] A Hash with a type, timestamp, and description key.
      def self.evaluate_result(result)
        if result['success']
          return {
            type: :aamva_success,
            description: 'AAMVA call succeeded',
          }
        end

        if result['timed_out']
          return {
            type: :aamva_timed_out,
            description: 'AAMVA request timed out.',
          }
        end

        if result['mva_exception']
          state = result['state_id_jurisdiction']
          return {
            type: :aamva_mva_exception,
            # rubocop:disable Layout/LineLength
            description: "AAMVA request failed because the MVA in #{state} failed to return a response.",
            # rubocop:enable Layout/LineLength
          }
        end

        if result['exception']

          description = 'AAMVA request resulted in an exception'

          m = /ExceptionText: (.+?),/.match(result['exception'])
          if m.present?
            description = "#{description} (#{m[1]})"
          end

          return {
            type: :aamva_exception,
            description:,
          }
        end

        # The API call failed because of actual errors in the user's data.
        # Try to come up with an explanation

        explanation = explain_errors(result) || 'Check logs for more info.'

        return {
          type: :aamva_error,
          description: "AAMVA request failed. #{explanation}",
        }
      end

      def self.explain_errors(result)
        # The values in the errors object are arrays
        attributes = {}
        result['errors']&.each do |key, values|
          attributes[key] = values.first
        end

        document_type = ID_TYPES[result['document_type_received']] || 'id card'
        state = result['state_id_jurisdiction']

        if mva_says_invalid_id_number?(attributes)
          # rubocop:disable Layout/LineLength
          return "The ID # from the user's #{document_type} was invalid according to the state of #{state}"
          # rubocop:enable Layout/LineLength
        end

        failed_attributes = relevant_failed_attributes(attributes)

        if !failed_attributes.empty?
          plural = failed_attributes.length == 1 ? '' : 's'

          # rubocop:disable Layout/LineLength
          "#{failed_attributes.length} attribute#{plural} failed to validate: #{failed_attributes.join(', ')}"
          # rubocop:enable Layout/LineLength
        end
      end

      def self.mva_says_invalid_id_number?(attributes)
        # When all attributes are marked "MISSING", except ID number,
        # which is marked "UNVERIFIED", that indicates the MVA could not
        # find the ID number to compare PII

        missing_count = attributes.count do |_attr, status|
          status == 'MISSING'
        end

        attributes['state_id_number'] == 'UNVERIFIED' && missing_count == attributes.count - 1
      end

      def self.relevant_failed_attributes(attributes)
        # 'UNVERIFIED' is a real mismatch, so always report it. 'MISSING' usually just means we
        # never sent the attribute (height, weight, sex...), so only report it where the proofer
        # requires a match.
        failed = attributes.select do |attr, status|
          status == 'UNVERIFIED' ||
            (status == 'MISSING' && REQUIRED_VERIFICATION_ATTRIBUTE_NAMES.include?(attr))
        end.keys

        # Required attributes first; they are the most likely cause.
        required, other = failed.partition do |attr|
          REQUIRED_VERIFICATION_ATTRIBUTE_NAMES.include?(attr)
        end

        required + other
      end
    end
  end
end
