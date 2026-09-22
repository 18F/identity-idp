# frozen_string_literal: true

module Proofing
  module Clear1
    class Response < ::FormResponse
      attr_reader :response_body

      def initialize(response_body:)
        @response_body = response_body

        super(
          success: success?,
          errors:,
          extra: extra_attributes,
        )
      rescue StandardError => e
        NewRelic::Agent.notice_error(e)
        super(
          success: false,
          errors:,
          extra: {
            backtrace: e.backtrace,
            exception: e,
          }
        )
      end

      def pii
        @pii ||= begin
          return nil unless success?
          traits = response_body.dig(:traits)

          return nil unless traits.present?
          document_data = traits&.[](:document)
          document_type_received = document_data[:document_type]

          proofed_user_pii = {
            first_name: traits[:first_name] || document_data[:first_name],
            last_name: traits[:last_name] || document_data[:last_name],
            middle_name: traits[:middle_name] || document_data[:middle_name],
            document_type_received:,
            phone: traits[:phone],
            ssn: SsnFormatter.normalize(traits[:ssn9]),
            address1: traits.dig(:address, :line1),
            address2: traits.dig(:address, :line2),
            city: traits.dig(:address, :city),
            state: traits.dig(:address, :state),
            zipcode: traits.dig(:address, :postal_code),
            issuing_country_code: document_data[:issuing_country],
            sex: traits[:gender],
            dob: document_data_date(document_data, :date_of_birth),
          }

          document_data = traits&.[](:document)

          if Idp::Constants::DocumentTypes::SUPPORTED_STATE_ID_TYPES.include?(document_type_received)
            proofed_user_pii.merge!(
              {
                state_id_expiration: document_data_date(document_data, :date_of_expiry),
                # state_id_issued:, not provided by Clear1
                state_id_jurisdiction: document_data[:issuing_subdivision],
                state_id_number: document_data[:document_number],
              },
            )
          elsif Idp::Constants::DocumentTypes::SUPPORTED_PASSPORT_TYPES.include?(document_type_received)
            proofed_user_pii.merge!(
              {
                passport_expiration: document_data_date(document_data, :date_of_expiry),
                passport_number: document_data[:document_number],
              },
            )
          end

          proofed_user_pii.with_indifferent_access
        end
      end

      def success?
        response_body[:authenticated] == true
      end

      private


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

      def document_data_date(document_data, key)
        date_hash = document_data.dig(key)
        return nil if date_hash.blank?

        Date.new(date_hash[:year], date_hash[:month], date_hash[:day])
      end

      def errors
        return nil if success?

        { clear1: true }
      end
    end
  end
end
