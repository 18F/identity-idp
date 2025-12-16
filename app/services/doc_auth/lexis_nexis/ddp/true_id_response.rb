# frozen_string_literal: true

module DocAuth
  module LexisNexis
    module Ddp
      class TrueIdResponse < DocAuth::Response # Todo: process DDP TrueID specific response details
        include ImageMetricsReader
        include DocPiiReader
        include ClassificationConcern
        include SelfieConcern
        # attr_reader :exception
        # attr_accessor :context,
        #               :success,
        #               :transaction_id,
        #               :review_status,
        #               :account_lex_id,
        #               :session_id,
        #               :response_body,
        #               :client

        attr_reader :config, :response_body, :passport_requested, :liveness_checking_enabled

        def initialize(response_body:, config:, passport_requested: false,
                       liveness_checking_enabled: false, request_context: {})
          @config = config
          @response_body = response_body
          @passport_requested = passport_requested
          @request_context = request_context
          @liveness_checking_enabled = liveness_checking_enabled
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
              reference: reference,
            },
          )
        end

        # rubocop:disable Style/OptionalArguments
        def add_error(key = :base, error)
          (@errors[key] ||= Set.new).add(error)
          self
        end
        # rubocop:enable Style/OptionalArguments

        def errors
          @errors.transform_values(&:to_a)
        end

        def errors?
          @errors.any?
        end

        def exception?
          !@exception.nil?
        end

        def failed?
          !exception? && errors?
        end

        def success?
          @success
        end

        def timed_out?
          @exception.is_a?(Proofing::TimeoutError)
        end

        def to_h
          {
            client: client,
            success: success?,
            errors: errors,
            exception: exception,
            timed_out: timed_out?,
            transaction_id: transaction_id,
            review_status: review_status,
            account_lex_id: account_lex_id,
            session_id: session_id,
            response_body: redacted_response_body,
          }
        end

        def device_fingerprint
          response_body&.dig('fuzzy_device_id')
        end

        private

        def successful_result?
          transaction_status == 'Passed' ## selfie_passed?
        end

        def redacted_response_body
          return response_body if response_body.blank?

          Proofing::LexisNexis::Ddp::ResponseRedacter.redact(response_body)
        end

        def tps_vendor_raw_response
          @tps_vendor_raw_response ||= response_body['integration_hub_results'].values.first.values.first.dig("tps_vendor_raw_response")
        end

        def products
          @products ||= tps_vendor_raw_response&.dig('Products')
        endq

        def status
          @products ||= tps_vendor_raw_response&.dig('Status')
        end
        
        def transaction_status
          status&.dig('TransactionStatus')
        end

        def parameter_details
          @parameter_details ||= products&.first&.dig('ParameterDetails')
        end

        def extra_attributes
          {}
        end

        def passport_card_detected?
          false
        end

        def id_type
          :drivers_license
        end

        def expected_document_type_received?
          true
        end

        def with_authentication_result?
          true_id_product&.dig(:AUTHENTICATION_RESULT).present?
        end

        def true_id_product
          response_body['auth_method'] == 'trueid'
        end

        def error_messages
          return {} if successful_result?

          if passport_card_detected?
            { passport_card: I18n.t('doc_auth.errors.doc.doc_type_check') }
          elsif id_type.present? && !expected_document_type_received?
            { unexpected_id_type: true, expected_id_type: expected_id_type }
          elsif with_authentication_result?
            ErrorGenerator.new(config).generate_doc_auth_errors(response_info)
          elsif true_id_product.present?
            ErrorGenerator.wrapped_general_error
          else
            { network: true } # return a generic technical difficulties error to user
          end
        end

        def read_pii
          if false # passport_submittal
            Pii::Passport.new(**Idp::Constants::MOCK_IDV_APPLICANT_WITH_PASSPORT)
          else
            Pii::StateId.new(**Idp::Constants::MOCK_IDV_APPLICANT)
          end
        end
      end
    end
  end
end

