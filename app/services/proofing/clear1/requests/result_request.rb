# frozen_string_literal: true

module Proofing
  module Clear1
    module Requests
      class ResultRequest < Proofing::Clear1::Request
        attr_reader :verification_session_id, :response_body

        def initialize(verification_session_id:)
          @verification_session_id = verification_session_id
        end

        private

        def metric_name
          'clear1_verification_data_request'
        end

        def handle_http_response(response)
          @response_body = JSON.parse(response.body, symbolize_names: true)

          if success?(response_body)
            success = true
            errors = nil
          else
            success = false
            errors = { clear1: true }
          end

          FormResponse.new(
            success:,
            errors: errors,
            extra: extra_attributes,
          )
        rescue => exception
          NewRelic::Agent.notice_error(exception)
          FormResponse.new(
            success: false,
            errors: { clear1: true },
            extra: extra_attributes.merge(exception:),
          )
        end

        def endpoint
          [
            IdentityConfig.store.idv_clear1_api_base_url,
            'v1',
            'verification_sessions',
            verification_session_id,
          ].join('/')
        end

        def success?(response_body)
          response_body[:authenticated] == true
        end

        def extra_attributes
          response_body.slice(
            :id,
            :object_name,
            :authenticated,
            :authentication_methods,
            :check_metadata,
            :checks,
            :created_at,
            :custom_fields,
            :expires_at,
            :fields_to_collect,
            :ial_status,
            :idv_status,
            :ip,
            :is_data_granted,
            :project_id,
            :redirect_url,
            :report_id,
            :status,
            :status_details,
            :status_reason,
            :token,
          ).merge(
            vendor_name: Idp::Constants::Vendors::CLEAR1,
          )
        end

        def pii
          return nil unless success?
          traits = response_body.dig(:traits)
          # document_type_received = document_data&.[](:document_type)

          # if Idp::Constants::DocumentTypes::PASSPORT_TYPES.include?(document_type_received)
          #   passport_data = Pii::Passport.members.index_with { |key| session[:pii_from_doc][key] }
          #   Pii::Passport.new(**passport_data)
          # elsif Idp::Constants::DocumentTypes::STATE_ID_TYPES.include?(document_type_received)
          #   Pii::StateId.new(**state_id_data)
          # end
        
          return nil unless traits.present?
          document_data = traits&.[](:document)
          document_type_received = document_data[:document_type]

          proofed_user_pii = {
            first_name: traits[:first_name] || document_data[:first_name],
            last_name: traits[:last_name] || document_data[:last_name],
            middle_name: traits[:middle_name] || document_data[:middle_name],
            document_type_received:,
            phone: traits[:phone],
            ssn: traits[:ssn],
            address1: traits.dig(:address, :line1),
            address2: traits.dig(:address, :line2),
            city: traits.dig(:address, :city),
            state: traits.dig(:address, :state),
            zipcode: traits.dig(:address, :postal_code),
            issuing_country_code: document_data[:issuing_country],
            sex: traits[:gender],
          }

          document_data = traits&.[](:document)
          
          if Idp::Constants::DocumentTypes::STATE_ID_TYPES.include?(document_type_received)
            proofed_user_pii.merge!({
              state_id_expiration: document_data_date(document_data, :date_of_expiry),
              # state_id_issued:, not provided by Clear1
              state_id_jurisdiction: document_data[:issuing_subdivision],
              state_id_number: document_data[:document_number],
            })
          elsif Idp::Constants::DocumentTypes::PASSPORT_TYPES.include?(document_type_received)
            proofed_user_pii.merge!({
              passport_expiration: document_data_date(document_data, :date_of_expiry),
              passport_number: document_data[:document_number],
            })
          end

          proofed_user_pii
        end

        def document_data_date(document_data, key)
          date_hash = document_data.dig(key)
          return nil unless date_hash&.[:date]

          Date.new(date_hash[:year], date_hash[:month], date_hash[:day])
        end
      end
    end
  end
end
