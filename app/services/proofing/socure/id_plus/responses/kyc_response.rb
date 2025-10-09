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

          def all_required_attributes_verified?
            (REQUIRED_ATTRIBUTES - verified_attributes).empty?
          end

          def reason_codes
            @reason_codes ||= kyc('reasonCodes').to_set.freeze
          end

          def verified_attributes
            VERIFIED_ATTRIBUTE_MAP.each_with_object([]) do |(attr_name, field_names), result|
              if Array(field_names).all? { |f| field_validations[f] }
                result << attr_name
              end
            end.to_set
          end

          private

          attr_reader :http_response

          def kyc(*fields)
            kyc_object = http_response.body['kyc']
            raise 'No kyc section on response' unless kyc_object
            kyc_object.dig(*fields)
          end

          def field_validations
            @field_validations ||= kyc('fieldValidations')
              .each_with_object({}) do |(field, valid), obj|
                obj[field.to_sym] = valid.round == 1
              end.freeze
          end
        end
      end
    end
  end
end
