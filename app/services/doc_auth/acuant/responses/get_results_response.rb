module DocAuth
  module Acuant
    module Responses
      class GetResultsResponse < DocAuth::Response
        attr_reader :config

        BARCODE_COULD_NOT_BE_READ_ERROR = '2D Barcode Read'.freeze

        def initialize(http_response, config)
          @http_response = http_response
          @config = config
          super(
            success: successful_result?,
            errors: generate_errors,
            extra: response_info,
          )
        end

        # @return [DocAuth::Acuant::ResultCode::ResultCode]
        def result_code
          DocAuth::Acuant::ResultCodes.from_int(parsed_response_body['Result'])
        end

        def tamper_result_code
          # TamperResult uses the same Acuant Enum as Result
          DocAuth::Acuant::ResultCodes.from_int(parsed_response_body&.dig('TamperResult'))
        end

        def pii_from_doc
          DocAuth::Acuant::PiiFromDoc.new(parsed_response_body).call
        end

        def attention_with_barcode?
          return false unless result_code == DocAuth::Acuant::ResultCodes::ATTENTION

          raw_alerts.all? do |alert|
            alert_result_code = DocAuth::Acuant::ResultCodes.from_int(alert['Result'])

            alert_result_code == DocAuth::Acuant::ResultCodes::PASSED ||
              (alert_result_code == DocAuth::Acuant::ResultCodes::ATTENTION &&
               alert['Key'] == BARCODE_COULD_NOT_BE_READ_ERROR)
          end
        end

        private

        attr_reader :http_response

        def response_info
          @response_info ||= create_response_info
        end

        def create_response_info
          alerts = processed_alerts

          log_alert_formatter = DocAuth::ProcessedAlertToLogAlertFormatter.new
          {
            vendor: 'Acuant',
            billed: result_code.billed,
            doc_auth_result: result_code.name,
            processed_alerts: alerts,
            alert_failure_count: alerts[:failed]&.count.to_i,
            log_alert_results: log_alert_formatter.log_alerts(alerts),
            image_metrics: processed_image_metrics,
            tamper_result: tamper_result_code&.name,
          }
        end

        def generate_errors
          return {} if successful_result?

          ErrorGenerator.new(config).generate_doc_auth_errors(response_info)
        end

        def parsed_response_body
          @parsed_response_body ||= JSON.parse(http_response.body)
        end

        def raw_alerts
          parsed_response_body['Alerts'] || []
        end

        def raw_regions
          parsed_response_body['Regions'] || []
        end

        def regions_by_id
          @regions_by_id ||= raw_regions.index_by { |region| region['Id'] }
        end

        def raw_images_data
          parsed_response_body['Images'] || []
        end

        def processed_alerts
          @processed_alerts ||= process_raw_alerts(raw_alerts)
        end

        def processed_image_metrics
          @processed_image_metrics ||= raw_images_data.index_by do |image|
            image.delete('Uri')
            get_image_side_name(image['Side'])
          end
        end

        def successful_result?
          passed_result? || attention_with_barcode?
        end

        def passed_result?
          result_code == DocAuth::Acuant::ResultCodes::PASSED
        end

        def get_image_side_name(side_number)
          side_number == 0 ? :front : :back
        end

        def get_image_info(image_id)
          @images_by_id ||= raw_images_data.index_by { |image| image['Id'] }

          @images_by_id[image_id]
        end

        def get_region_info(region_ids)
          region = regions_by_id[region_ids.first]
          image = get_image_info(region['ImageReference'])

          {
            region: region['Key'],
            side: get_image_side_name(image['Side']),
          }
        end

        def process_raw_alerts(alerts)
          processed_alerts = { passed: [], failed: [] }
          alerts.each do |raw_alert|
            region_refs = raw_alert['RegionReferences']
            result_code = DocAuth::Acuant::ResultCodes.from_int(raw_alert['Result'])

            new_alert = {
              name: raw_alert['Key'],
              result: result_code.name,
            }

            new_alert.merge!(get_region_info(region_refs)) if region_refs.present?

            if result_code != DocAuth::Acuant::ResultCodes::PASSED
              processed_alerts[:failed].push(new_alert)
            else
              processed_alerts[:passed].push(new_alert)
            end
          end

          processed_alerts
        end
      end
    end
  end
end
