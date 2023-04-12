module DocAuth
  module Mock
    class ResultResponse < DocAuth::Response
      attr_reader :uploaded_file, :config

      def initialize(uploaded_file, config)
        @uploaded_file = uploaded_file.to_s
        @config = config
        super(
          success: success?,
          errors: errors,
          pii_from_doc: pii_from_doc,
          extra: {
            doc_auth_result: doc_auth_result,
            billed: true,
          },
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
            liveness_result = file_data.dig('liveness_result')

            if [doc_auth_result, image_metrics, failed, passed, liveness_result].any?(&:present?)
              mock_args = {}
              mock_args[:doc_auth_result] = doc_auth_result if doc_auth_result.present?
              mock_args[:image_metrics] = image_metrics.symbolize_keys if image_metrics.present?
              mock_args[:failed] = failed.map!(&:symbolize_keys) if failed.present?
              mock_args[:passed] = passed.map!(&:symbolize_keys) if passed.present?
              mock_args[:liveness_result] = liveness_result if liveness_result.present?

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
        errors.blank? || attention_with_barcode?
      end

      def attention_with_barcode?
        parsed_alerts == [ATTENTION_WITH_BARCODE_ALERT]
      end

      private

      def parsed_alerts
        parsed_data_from_uploaded_file&.dig('failed_alerts')
      end

      def parsed_data_from_uploaded_file
        return @parsed_data_from_uploaded_file if defined?(@parsed_data_from_uploaded_file)

        @parsed_data_from_uploaded_file = parse_uri || parse_yaml
      end

      def doc_auth_result
        doc_auth_result_from_uploaded_file || doc_auth_result_from_success
      end

      def doc_auth_result_from_uploaded_file
        parsed_data_from_uploaded_file&.[]('doc_auth_result')
      end

      def doc_auth_result_from_success
        if success?
          DocAuth::Acuant::ResultCodes::PASSED.name
        else
          DocAuth::Acuant::ResultCodes::CAUTION.name
        end
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

      def parse_yaml
        data = YAML.safe_load(uploaded_file, permitted_classes: [Date])
        if data.is_a?(Hash)
          if (m = data.dig('document', 'dob').to_s.
            match(%r{(?<month>\d{1,2})/(?<day>\d{1,2})/(?<year>\d{4})}))
            data['document']['dob'] = Date.new(m[:year].to_i, m[:month].to_i, m[:day].to_i)
          end

          if data.dig('document', 'zipcode')
            data['document']['zipcode'] = data.dig('document', 'zipcode').to_s
          end

          JSON.parse(data.to_json) # converts Dates back to strings
        else
          { general: ["YAML data should have been a hash, got #{data.class}"] }
        end
      rescue Psych::SyntaxError
        if uploaded_file.ascii_only? # don't want this error for images
          { general: ['invalid YAML file'] }
        else
          {}
        end
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
        liveness_result: nil,
        image_metrics: DEFAULT_IMAGE_METRICS
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
          portrait_match_results: { FaceMatchResult: liveness_result },
        }
      end
    end
  end
end
