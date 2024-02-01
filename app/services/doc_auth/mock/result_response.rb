module DocAuth
  module Mock
    class ResultResponse < DocAuth::Response
      include DocAuth::ClassificationConcern
      include DocAuth::SelfieConcern
      include DocAuth::Mock::YmlLoaderConcern

      attr_reader :uploaded_file, :config

      def initialize(uploaded_file, selfie_check_performed, config)
        @uploaded_file = uploaded_file.to_s
        @selfie_check_performed = selfie_check_performed
        @config = config
        super(
          success: success?,
          errors: errors,
          pii_from_doc: pii_from_doc,
          doc_type_supported: id_type_supported?,
          selfie_check_performed: selfie_check_performed,
          selfie_live: selfie_live?,
          selfie_quality_good: selfie_quality_good?,
          extra: {
            doc_auth_result: doc_auth_result,
            portrait_match_results: portrait_match_results,
            billed: true,
            classification_info: classification_info,
          }.compact,
        )
      end

      def errors
        @errors ||= begin
          file_data = parsed_data_from_uploaded_file

          if file_data.blank? || attention_with_barcode?
            {}
          else
            doc_auth_result = file_data.dig('doc_auth_result')
            image_metrics = file_data.dig('image_metrics')
            failed = file_data.dig('failed_alerts')
            passed = file_data.dig('passed_alerts')
            face_match_result = file_data.dig('portrait_match_results', 'FaceMatchResult')
            classification_info = file_data.dig('classification_info')
            # Pass and doc type is ok
            has_fields = [
              doc_auth_result,
              image_metrics,
              failed,
              passed,
              face_match_result,
              classification_info,
            ].any?(&:present?)

            if has_fields
              # Error generator is not to be called when it's not failure
              # allows us to test successful results
              return {} if all_doc_capture_values_passing?(
                doc_auth_result, id_type_supported?
              )

              mock_args = {}
              mock_args[:doc_auth_result] = doc_auth_result if doc_auth_result.present?
              mock_args[:image_metrics] = image_metrics.symbolize_keys if image_metrics.present?
              mock_args[:failed] = failed.map!(&:symbolize_keys) unless failed.nil?
              mock_args[:passed] = passed.map!(&:symbolize_keys) if passed.present?
              mock_args[:liveness_enabled] = @selfie_check_performed
              mock_args[:classification_info] = classification_info if classification_info.present?
              fake_response_info = create_response_info(**mock_args)
              ErrorGenerator.new(config).generate_doc_auth_errors(fake_response_info)
            elsif file_data.include?(:general) # general is the key for errors from parsing
              file_data
            end
          end
        end
      end

      def pii_from_doc
        if parsed_data_from_uploaded_file.present?
          raw_pii = parsed_data_from_uploaded_file['document']
          raw_pii&.symbolize_keys || {}
        else
          Idp::Constants::MOCK_IDV_APPLICANT
        end
      end

      def success?
        (errors.blank? || attention_with_barcode?) && id_type_supported?
      end

      def attention_with_barcode?
        parsed_alerts == [ATTENTION_WITH_BARCODE_ALERT]
      end

      def self.create_image_error_response(status, side)
        errors = case status
                when 438
                  {
                    general: [Errors::IMAGE_LOAD_FAILURE],
                    side.to_sym => [Errors::IMAGE_LOAD_FAILURE_FIELD],
                  }
                when 439
                  {
                    general: [Errors::PIXEL_DEPTH_FAILURE],
                    side.to_sym => [Errors::IMAGE_LOAD_FAILURE_FIELD],
                  }
                when 440
                  {
                    general: [Errors::IMAGE_SIZE_FAILURE],
                    side.to_sym => [Errors::IMAGE_SIZE_FAILURE_FIELD],
                  }
                end
        message = [
          'Unexpected HTTP response',
          status,
        ].join(' ')
        exception = DocAuth::RequestError.new(message, status)
        DocAuth::Response.new(
          success: false,
          errors: errors,
          exception: exception,
          extra: { vendor: 'Mock' },
        )
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
        doc_auth_result_from_uploaded_file == 'Passed' || errors.blank?
      end

      def selfie_status
        return :not_processed if portrait_match_results&.dig(:FaceMatchResult).nil?
        portrait_match_results[:FaceMatchResult] == 'Pass' ? :success : :fail
      end

      private

      def parsed_alerts
        parsed_data_from_uploaded_file&.dig('failed_alerts')
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

      def portrait_match_results
        parsed_data_from_uploaded_file.dig('portrait_match_results')&.
          transform_keys! { |key| key.to_s.camelize }&.
          deep_symbolize_keys
      end

      def classification_info
        info = parsed_data_from_uploaded_file&.[]('classification_info') || {}
        info.to_h.symbolize_keys
      end

      def doc_auth_result_from_success
        if success?
          DocAuth::Acuant::ResultCodes::PASSED.name
        else
          DocAuth::Acuant::ResultCodes::CAUTION.name
        end
      end

      def all_doc_capture_values_passing?(doc_auth_result, id_type_supported)
        doc_auth_result == 'Passed' &&
          id_type_supported &&
          (@selfie_check_performed ? selfie_passed? : true)
      end

      def selfie_passed?
        selfie_status == :success
      end

      def parse_uri
        uri = URI.parse(uploaded_file.chomp)
        if uri.scheme == 'data'
          {}
        else
          { general: ["parsed URI, but scheme was #{uri.scheme} (expected data)"] }
        end
      rescue URI::InvalidURIError
        # no-op, allows falling through to YAML parsing
      end

      ATTENTION_WITH_BARCODE_ALERT = { 'name' => '2D Barcode Read', 'result' => 'Attention' }.freeze
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
        doc_auth_result: 'Failed',
        passed: [],
        failed: DEFAULT_FAILED_ALERTS,
        liveness_enabled: false,
        image_metrics: DEFAULT_IMAGE_METRICS,
        classification_info: nil
      )
        merged_image_metrics = DEFAULT_IMAGE_METRICS.deep_merge(image_metrics)
        {
          vendor: 'Mock',
          doc_auth_result: doc_auth_result,
          processed_alerts: {
            passed: passed,
            failed: failed,
          },
          alert_failure_count: failed&.count.to_i,
          image_metrics: merged_image_metrics,
          liveness_enabled: liveness_enabled,
          classification_info: classification_info,
          portrait_match_results: @selfie_check_performed ? portrait_match_results : nil,
        }.compact
      end
    end
  end
end
