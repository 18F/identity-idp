# frozen_string_literal: true

module DocAuth
  module Socure
    module Responses
      class DocvResultResponse < DocAuth::Response
        attr_reader :http_response

        DATA_PATHS = {
          reference_id: %w[referenceId],
          status: %w[status],
          msg: %w[msg],
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
          customer_profile: %w[customerProfile],
          socure_customer_user_id: %w[customerProfile customerUserId],
          socure_user_id: %w[customerProfile userId],
        }.freeze

        def initialize(http_response:)
          @http_response = http_response
          @pii_from_doc = read_pii

          super(
            success: doc_auth_success?,
            errors: error_messages,
            pii_from_doc:,
            extra: extra_attributes,
          )
        rescue StandardError => e
          NewRelic::Agent.notice_error(e)
          super(
            success: false,
            errors: { network: true },
            exception: e,
            extra: {
              backtrace: e.backtrace,
            }
          )
        end

        def doc_auth_success?
          id_type_supported? && successful_result? && !portrait_matching_failed?
        end

        def selfie_status
          return :not_processed if reason_codes&.intersect? reason_codes_selfie_not_processed
          return :fail if reason_codes&.intersect? reason_codes_selfie_fail

          if reason_codes&.intersect? reason_codes_selfie_pass
            return :success
          end

          :not_processed
        end

        def liveness_enabled
          selfie_status != :not_processed
        end

        def extra_attributes
          {
            address_line2_present: address2.present?,
            birth_year: dob&.year,
            customer_profile: get_data(DATA_PATHS[:customer_profile]),
            customer_user_id: get_data(DATA_PATHS[:socure_customer_user_id]),
            decision: get_data(DATA_PATHS[:decision]),
            doc_auth_success: doc_auth_success?,
            document_type: get_data(DATA_PATHS[:document_type]),
            flow_path: nil,
            id_doc_type:,
            issue_year: state_id_issued&.year,
            liveness_enabled:,
            reason_codes:,
            reference_id: get_data(DATA_PATHS[:reference_id]),
            state:,
            vendor: 'Socure',
            vendor_status: get_data(DATA_PATHS[:status]),
            vendor_status_message: get_data(DATA_PATHS[:msg]),
            zip_code: zipcode,
          }
        end

        private

        def successful_result?
          get_data(DATA_PATHS[:decision_value]) == 'accept'
        end

        def error_messages
          if !id_type_supported?
            { unaccepted_id_type: true }
          elsif !successful_result?
            { socure: { reason_codes: } }
          elsif portrait_matching_failed?
            { selfie_fail: true }
          else
            {}
          end
        end

        def read_pii
          Pii::StateId.new(
            first_name: get_data(DATA_PATHS[:first_name]),
            middle_name: get_data(DATA_PATHS[:middle_name]),
            last_name: get_data(DATA_PATHS[:last_name]),
            name_suffix: nil,
            address1: get_data(DATA_PATHS[:address1]),
            address2:,
            city: get_data(DATA_PATHS[:city]),
            state: get_data(DATA_PATHS[:state]),
            zipcode: get_data(DATA_PATHS[:zipcode]),
            dob:,
            sex: nil,
            height: nil,
            weight: nil,
            eye_color: nil,
            state_id_number: get_data(DATA_PATHS[:document_number]),
            state_id_issued:,
            state_id_expiration: parse_date(get_data(DATA_PATHS[:expiration_date])),
            id_doc_type: id_doc_type,
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

        def state
          get_data(DATA_PATHS[:state])
        end

        def zipcode
          get_data(DATA_PATHS[:zipcode])
        end

        def state_id_issued
          parse_date(get_data(DATA_PATHS[:issue_date]))
        end

        def id_doc_type
          document_id_type&.gsub(/\W/, '')&.underscore
        end

        def document_id_type
          get_data(DATA_PATHS[:id_type])
        end

        def dob
          parse_date(get_data(DATA_PATHS[:dob]))
        end

        def address2
          get_data(DATA_PATHS[:address2])
        end

        def reason_codes
          get_data(DATA_PATHS[:reason_codes])
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

        def id_type_supported?
          DocAuth::Response::STATE_ID_TYPE_SLUGS.key?(document_id_type)
        end

        def reason_codes_selfie_pass
          IdentityConfig.store.idv_socure_reason_codes_docv_selfie_pass
        end

        def reason_codes_selfie_fail
          IdentityConfig.store.idv_socure_reason_codes_docv_selfie_fail
        end

        def reason_codes_selfie_not_processed
          IdentityConfig.store.idv_socure_reason_codes_docv_selfie_not_processed
        end

        def portrait_matching_failed?
          selfie_status == :fail
        end
      end
    end
  end
end
