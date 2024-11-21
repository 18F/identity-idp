# frozen_string_literal: true

module DocAuth
  module Socure
    module Responses
      class DocvResultResponse < DocAuth::Response
        attr_reader :http_response, :biometric_comparison_required

        DATA_PATHS = {
          reference_id: %w[referenceId],
          document_verification: %w[documentVerification],
          reason_codes: %w[documentVerification reasonCodes],
          document_type: %w[documentVerification documentType],
          id_type: %w[documentVerification documentType type],
          issuing_state: %w[documentVerification documentType state],
          issuing_country: %w[documentVerification documentType country],
          decision: %w[documentVerification decision],
          decision_name: %w[documentVerification decision name],
          decision_value: %w[documentVerification decision value],
          document_data: %w[documentVerification documentData],
          first_name: %w[documentVerification documentData firstName],
          middle_name: %w[documentVerification documentData middleName],
          last_name: %w[documentVerification documentData surName],
          address1: %w[documentVerification documentData parsedAddress physicalAddress],
          address2: %w[documentVerification documentData parsedAddress physicalAddress2],
          city: %w[documentVerification documentData parsedAddress city],
          state: %w[documentVerification documentData parsedAddress state],
          zipcode: %w[documentVerification documentData parsedAddress zip],
          dob: %w[documentVerification documentData dob],
          document_number: %w[documentVerification documentData documentNumber],
          issue_date: %w[documentVerification documentData issueDate],
          expiration_date: %w[documentVerification documentData expirationDate],
        }.freeze

        def initialize(http_response:, biometric_comparison_required: false)
          @http_response = http_response

          # KLUDGE
          if rand < 0.5
            parsed_response_body['documentVerification']['decision']['value'] = 'reject'
          end

          @biometric_comparison_required = biometric_comparison_required
          @pii_from_doc = read_pii

          super(
            success: successful_result?,
            errors: error_messages,
            extra: extra_attributes,
            pii_from_doc: @pii_from_doc,
          )
        rescue StandardError => e
          NewRelic::Agent.notice_error(e)
          super(
            success: false,
            errors: { network: true },
            exception: e,
            extra: {
              backtrace: e.backtrace,
            },
          )
        end

        def doc_auth_success?
          success?
        end

        def selfie_status
          :not_processed
        end

        private

        def successful_result?
          get_data(DATA_PATHS[:decision_value]) == 'accept'
        end

        def error_messages
          return {} if successful_result?

          # reason_code = get_data(DATA_PATHS[:reason_codes])

          # KLUDGE
          reason_code = %w[R820 I849 R827 I808 R845 I856].sample

          {
            reason_codes: [reason_code],
          }
        end

        def extra_attributes
          {
            reference_id: get_data(DATA_PATHS[:reference_id]),
            decision: get_data(DATA_PATHS[:decision]),
            biometric_comparison_required: biometric_comparison_required,
          }
        end

        def read_pii
          Pii::StateId.new(
            first_name: get_data(DATA_PATHS[:first_name]),
            middle_name: get_data(DATA_PATHS[:middle_name]),
            last_name: get_data(DATA_PATHS[:last_name]),
            address1: get_data(DATA_PATHS[:address1]),
            address2: get_data(DATA_PATHS[:address2]),
            city: get_data(DATA_PATHS[:city]),
            state: get_data(DATA_PATHS[:state]),
            zipcode: get_data(DATA_PATHS[:zipcode]),
            dob: parse_date(get_data(DATA_PATHS[:dob])),
            state_id_number: get_data(DATA_PATHS[:document_number]),
            state_id_issued: parse_date(get_data(DATA_PATHS[:issue_date])),
            state_id_expiration: parse_date(get_data(DATA_PATHS[:expiration_date])),
            state_id_type: state_id_type,
            state_id_jurisdiction: get_data(DATA_PATHS[:issuing_state]),
            issuing_country_code: get_data(DATA_PATHS[:issuing_country]),
          )
        end

        def get_data(path)
          parsed_response_body.dig(*path)
        end

        def parsed_response_body
          @parsed_response_body ||= begin
            http_response&.body.present? ? JSON.parse(
              http_response.body,
            ).with_indifferent_access : {}
          rescue JSON::JSONError
            {}
          end
        end

        def state_id_type
          type = get_data(DATA_PATHS[:id_type])
          type&.gsub(/\W/, '')&.underscore
        end

        def parse_date(date_string)
          Date.parse(date_string)
        rescue ArgumentError, TypeError
          message = {
            event: 'Failure to parse Socure ID+ date',
          }.to_json
          Rails.logger.info(message)
          nil
        end
      end
    end
  end
end
