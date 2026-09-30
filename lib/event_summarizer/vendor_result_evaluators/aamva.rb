# frozen_string_literal: true

module EventSummarizer
  module VendorResultEvaluators
    module Aamva
      ID_TYPES = {
        'state_id_card' => 'non-driving ID card',
        'drivers_license' => "drivers' license",
      }.freeze

      UNVERIFIED = 'UNVERIFIED'
      MISSING = 'MISSING'

      ID_NUMBER = 'state_id_number'

      REQUIRED_VERIFICATION_ATTRIBUTES = %w[
        state_id_number
        dob
        last_name
        first_name
      ].freeze

      REQUIRED_IF_PRESENT_ATTRIBUTES = %w[
        state_id_expiration
      ].freeze

      def self.evaluate_result(result)
        if result['success']
          {
            type: :aamva_success,
            description: 'AAMVA call succeeded',
          }
        elsif result['timed_out']
          {
            type: :aamva_timed_out,
            description: 'AAMVA request timed out.',
          }
        elsif result['mva_exception']
          {
            type: :aamva_mva_exception,
            description: "AAMVA request failed because the MVA in " \
                         "#{result['state_id_jurisdiction']} failed to return a response.",
          }
        elsif result['exception']
          {
            type: :aamva_exception,
            description: exception_description(result['exception']),
          }
        else
          explanation = explain_errors(result) || 'Check logs for more info.'

          {
            type: :aamva_error,
            description: "AAMVA request failed. #{explanation}",
          }
        end
      end

      def self.exception_description(exception)
        description = 'AAMVA request resulted in an exception'
        exception_text = exception.to_s[/ExceptionText: (.+?),/, 1]

        return description if exception_text.nil?

        "#{description} (#{exception_text})"
      end

      def self.explain_errors(result)
        attributes = attribute_statuses(result['errors'])

        if mva_says_invalid_id_number?(attributes)
          invalid_id_number_description(result)
        else
          failed_attributes_description(relevant_failed_attributes(attributes))
        end
      end

      def self.invalid_id_number_description(result)
        document_type = ID_TYPES[result['document_type_received']] || 'id card'

        "The ID # from the user's #{document_type} was invalid according to " \
          "the state of #{result['state_id_jurisdiction']}"
      end

      def self.failed_attributes_description(failed_attributes)
        return if failed_attributes.empty?

        plural = failed_attributes.length == 1 ? '' : 's'

        "#{failed_attributes.length} attribute#{plural} " \
          "failed to validate: #{failed_attributes.join(', ')}"
      end

      def self.attribute_statuses(errors)
        errors.to_h.transform_values(&:first)
      end

      def self.mva_says_invalid_id_number?(attributes)
        return false unless attributes[ID_NUMBER] == UNVERIFIED

        attributes.except(ID_NUMBER).values.all?(MISSING)
      end

      def self.relevant_failed_attributes(attributes)
        blocking_failures = []
        other_failures = []

        attributes.each do |attribute, status|
          next unless failed?(attribute, status)

          if blocking?(attribute)
            blocking_failures << attribute
          else
            other_failures << attribute
          end
        end

        blocking_failures + other_failures
      end

      def self.failed?(attribute, status)
        status == UNVERIFIED || (status == MISSING && required?(attribute))
      end

      # An attribute the state contradicted, where that contradiction is what failed the request.
      def self.blocking?(attribute)
        required?(attribute) || required_if_present?(attribute)
      end

      def self.required?(attribute)
        REQUIRED_VERIFICATION_ATTRIBUTES.include?(attribute)
      end

      def self.required_if_present?(attribute)
        REQUIRED_IF_PRESENT_ATTRIBUTES.include?(attribute)
      end
    end
  end
end
