# frozen_string_literal: true

module Proofing
  module Socure
    module IdPlus
      module Responses
        class KycResponse < Proofing::Socure::IdPlus::Response
          VERIFIED_ATTRIBUTE_MAP = {
            address: %i[streetAddress city state zip].freeze,
            first_name: :firstName,
            last_name: :surName,
            phone: :mobileNumber,
            ssn: :ssn,
            dob: :dob,
          }.freeze

          REQUIRED_ATTRIBUTES = %i[
            first_name
            last_name
            address
            dob
            ssn
          ].to_set.freeze

          # Failed attributes we report by name so AAMVA coverage can rescue the result.
          # Anything else is reported as :unknown, which never appears in aamva_verified_attributes.
          REPORTABLE_FAILED_ATTRIBUTES = %i[address dob ssn].to_set.freeze

          def all_required_attributes_verified?
            (REQUIRED_ATTRIBUTES - verified_attributes).empty?
          end

          def attributes_requiring_additional_verification
            (REQUIRED_ATTRIBUTES - verified_attributes)
              .map { |attribute| reportable_failed_attribute(attribute) }
              .uniq.sort
          end

          def failed_result_can_pass_with_additional_verification?
            return false if successful?
            return false if has_autofail_reason_codes?

            attributes_requiring_additional_verification.any?
          end

          def reason_codes
            @reason_codes ||= kyc('reasonCodes').to_set.freeze
          end

          def successful?
            all_required_attributes_verified? && !has_autofail_reason_codes?
          end

          def verified_attributes
            VERIFIED_ATTRIBUTE_MAP.each_with_object([]) do |(attr_name, field_names), result|
              if Array(field_names).all? { |f| field_validations[f] }
                result << attr_name
              end
            end.to_set
          end

          def field_validations
            @field_validations ||= kyc('fieldValidations')
              .each_with_object({}) do |(field, valid), obj|
                obj[field.to_sym] = valid.round == 1
              end.freeze
          end

          def vendor_id
            kyc('socureId')
          end

          def source_attribution
            kyc('sourceAttribution') || []
          end

          def has_autofail_reason_codes?
            (reason_codes & auto_failure_reason_codes).any?
          end

          def auto_failure_reason_codes
            @auto_failure_reason_codes ||=
              IdentityConfig.store.idv_socure_kyc_auto_failure_reason_codes
          end

          private

          attr_reader :http_response

          def reportable_failed_attribute(attribute)
            REPORTABLE_FAILED_ATTRIBUTES.include?(attribute) ? attribute : :unknown
          end

          def kyc(*fields)
            kyc_object = http_response.body['kyc']
            raise 'No kyc section on response' unless kyc_object
            kyc_object.dig(*fields)
          end
        end
      end
    end
  end
end
