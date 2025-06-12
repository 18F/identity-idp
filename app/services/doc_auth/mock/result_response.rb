# frozen_string_literal: true

module DocAuth
  module Mock
    class ResultResponse < DocAuth::Response
      include DocAuth::ClassificationConcern
      include DocAuth::SelfieConcern
      include DocAuth::Mock::YmlLoaderConcern

      attr_reader :uploaded_file, :config

      def initialize(uploaded_file, config, selfie_required = false, passport_submittal = false)
        @uploaded_file = uploaded_file.to_s
        @config = config
        @selfie_required = selfie_required
        @passport_submittal = passport_submittal
        super(
          success: success?,
          errors:,
          pii_from_doc:,
          doc_type_supported: id_type_supported?,
          selfie_live: selfie_live?,
          selfie_quality_good: selfie_quality_good?,
          selfie_status: selfie_status,
          extra: {
            transaction_status:,
            doc_auth_result:,
            passport_check_result:,
            portrait_match_results:,
            billed: true,
            classification_info:,
            workflow: workflow,
            liveness_checking_required: @selfie_required,
            **@response_info.to_h,
          },
        )
      end

      def errors
        @errors ||= begin
          file_data = parsed_data_from_uploaded_file

          if file_data.blank?
            {}
          else
            transaction_status = file_data.dig('transaction_status')
            doc_auth_result = file_data.dig('doc_auth_result')
            image_metrics = file_data.dig('image_metrics')
            failed = file_data.dig('failed_alerts')&.dup
            passed = file_data.dig('passed_alerts')
            face_match_result = file_data.dig('portrait_match_results', 'FaceMatchResult')
            classification_info = file_data.dig('classification_info')&.symbolize_keys
            passport_check_result = file_data.dig('passport_check_result', 'PassportCheckResult')
            # Pass and doc type is ok
            has_fields = [
              transaction_status,
              doc_auth_result,
              image_metrics,
              failed,
              passed,
              face_match_result,
              classification_info,
              passport_check_result,
            ].any?(&:present?)

            if has_fields
              # Error generator is not to be called when it's not failure
              # allows us to test successful results
              return {} if all_doc_capture_values_passing?(
                transaction_status, id_type_supported?
              )

              mock_args = {}
              mock_args[:transaction_status] = transaction_status if transaction_status.present?
              mock_args[:doc_auth_result] = doc_auth_result if doc_auth_result.present?
              mock_args[:image_metrics] = image_metrics.symbolize_keys if image_metrics.present?
              mock_args[:failed] = failed.map!(&:symbolize_keys) unless failed.nil?
              mock_args[:passed] = passed.map!(&:symbolize_keys) if passed.present?
              mock_args[:liveness_enabled] = face_match_result ? true : false
              mock_args[:classification_info] = classification_info if classification_info.present?
              if passport_check_result.present?
                mock_args[:passport_check_result] =
                  classification_info
              end
              @response_info = create_response_info(**mock_args)
              ErrorGenerator.new(config).generate_doc_auth_errors(@response_info)
            elsif file_data.include?(:general) # general is the key for errors from parsing
              file_data
            end
          end
        end
      end

      def pii_from_doc
        if parsed_data_from_uploaded_file.present?
          parsed_pii_from_doc
        elsif @passport_submittal == true
          Pii::Passport.new(**Idp::Constants::MOCK_IDV_APPLICANT_WITH_PASSPORT)
        else
          Pii::StateId.new(**Idp::Constants::MOCK_IDV_APPLICANT)
        end
      end

      def success?
        doc_auth_success? && (@selfie_required ? selfie_passed? : true)
      end

      def attention_with_barcode?
        !!parsed_alerts
          &.any? { |alert| alert['name'] == '2D Barcode Read' && alert['result'] == 'Attention' }
      end

      def self.create_network_error_response
        errors = { network: true }
        DocAuth::Response.new(
          success: false,
          errors: errors,
          exception: Faraday::TimeoutError.new,
          extra: { vendor: 'Mock' },
        )
      end

      def doc_auth_success?
        return false unless id_type_supported?
        return false if transaction_status_from_uploaded_file ==
                        LexisNexis::TransactionCodes::FAILED.name
        return true if transaction_status_from_uploaded_file ==
                       LexisNexis::TransactionCodes::PASSED.name
        return false if doc_auth_result_from_uploaded_file == LexisNexis::ResultCodes::FAILED.name

        doc_auth_result_from_uploaded_file == LexisNexis::ResultCodes::PASSED.name ||
          errors.blank? ||
          (attention_with_barcode? && parsed_alerts.length == 1)
      end

      def selfie_status
        if @selfie_required
          return :success if portrait_match_results&.dig(:FaceMatchResult).nil?
          portrait_match_results[:FaceMatchResult] == 'Pass' ? :success : :fail
        else
          :not_processed
        end
      end

      def workflow
        selfie_check_performed? ? 'test_liveness_workflow' : 'test_non_liveness_workflow'
      end

      def passport_check_result
        return {} if !parsed_data_from_uploaded_file.has_key?('passport_check_result')

        parsed_data_from_uploaded_file.dig('passport_check_result')
          &.transform_keys! { |key| key.to_s.camelize }
          &.deep_symbolize_keys
      end

      private

      def parsed_alerts
        parsed_data_from_uploaded_file&.dig('failed_alerts')
      end

      def parsed_pii_from_doc
        return if !parsed_data_from_uploaded_file.has_key?('document')

        if parsed_data_from_uploaded_file['document']['id_doc_type'] == 'passport'
          Pii::Passport.new(
            **Idp::Constants::MOCK_IDV_APPLICANT.merge(
              parsed_data_from_uploaded_file['document'].symbolize_keys,
            ).slice(*Pii::Passport.members),
          )
        else
          Pii::StateId.new(
            **Idp::Constants::MOCK_IDV_APPLICANT.merge(
              parsed_data_from_uploaded_file['document'].symbolize_keys,
            ).slice(*Pii::StateId.members),
          )
        end
      end

      def parsed_data_from_uploaded_file
        return @parsed_data_from_uploaded_file if defined?(@parsed_data_from_uploaded_file)

        @parsed_data_from_uploaded_file = parse_uri || parse_yaml(uploaded_file)
      end

      def doc_auth_result
        doc_auth_result_from_uploaded_file || doc_auth_result_from_success
      end

      def doc_auth_result_from_uploaded_file
        parsed_data_from_uploaded_file&.[]('doc_auth_result')
      end

      def transaction_status
        transaction_status_from_uploaded_file || transaction_status_from_success
      end

      def transaction_status_from_uploaded_file
        parsed_data_from_uploaded_file&.[]('transaction_status')
      end

      def portrait_match_results
        parsed_data_from_uploaded_file.dig('portrait_match_results')
          &.transform_keys! { |key| key.to_s.camelize }
          &.deep_symbolize_keys
      end

      def classification_info
        info = parsed_data_from_uploaded_file&.[]('classification_info') || {}
        info.to_h.symbolize_keys
      end

      def doc_auth_result_from_success
        if doc_auth_success?
          LexisNexis::ResultCodes::PASSED.name
        else
          LexisNexis::ResultCodes::CAUTION.name
        end
      end

      def transaction_status_from_success
        if doc_auth_success?
          LexisNexis::TransactionCodes::PASSED.name
        else
          LexisNexis::TransactionCodes::FAILED.name
        end
      end

      def all_doc_capture_values_passing?(transaction_status, id_type_supported)
        transaction_status == LexisNexis::TransactionCodes::PASSED.name &&
          id_type_supported &&
          (selfie_check_performed? ? selfie_passed? : true)
      end

      def selfie_passed?
        selfie_status == :success
      end

      def parse_uri
        return nil if !uploaded_file || !uploaded_file.ascii_only?
        uri = URI.parse(uploaded_file.chomp)
        if uri.scheme == 'data'
          {}
        else
          { general: ["parsed URI, but scheme was #{uri.scheme} (expected data)"] }
        end
      rescue URI::InvalidURIError
        # no-op, allows falling through to YAML parsing
      end

      DEFAULT_FAILED_ALERTS = [{ name: '2D Barcode Read', result: 'Failed' }].freeze
      DEFAULT_IMAGE_METRICS = {
        front: {
          'VerticalResolution' => 600,
          'HorizontalResolution' => 600,
          'GlareMetric' => 100,
          'SharpnessMetric' => 100,
        },
        back: {
          'VerticalResolution' => 600,
          'HorizontalResolution' => 600,
          'GlareMetric' => 100,
          'SharpnessMetric' => 100,
        },
      }.freeze

      def create_response_info(
            transaction_status: LexisNexis::TransactionCodes::FAILED.name,
            doc_auth_result: LexisNexis::ResultCodes::FAILED.name,
            passed: [],
            failed: DEFAULT_FAILED_ALERTS,
            liveness_enabled: false,
            image_metrics: DEFAULT_IMAGE_METRICS,
            classification_info: nil,
            passport_check_result: nil
          )
        merged_image_metrics = DEFAULT_IMAGE_METRICS.deep_merge(image_metrics)
        {
          vendor: 'Mock',
          transaction_status:,
          doc_auth_result:,
          processed_alerts: {
            passed: passed,
            failed: failed,
          },
          alert_failure_count: failed&.count.to_i,
          image_metrics: merged_image_metrics,
          liveness_enabled:,
          classification_info:,
          portrait_match_results: selfie_check_performed? ? portrait_match_results : nil,
          passport_check_result:,
        }
      end
    end
  end
end
