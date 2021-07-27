require 'identity_doc_auth/acuant/pii_from_doc'
require 'identity_doc_auth/acuant/result_codes'
require 'identity_doc_auth/response'
require 'identity_doc_auth/error_generator'

module IdentityDocAuth
  module Acuant
    module Responses
      class GetResultsResponse < IdentityDocAuth::Response
        attr_reader :config

        BARCODE_COULD_NOT_BE_READ_ERROR = '2D Barcode Read'.freeze

        def initialize(http_response, config)
          @http_response = http_response
          @config = config
          super(
            success: successful_result?,
            errors: generate_errors,
            extra: {
              result: result_code.name,
              billed: result_code.billed,
              processed_alerts: processed_alerts,
              alert_failure_count: processed_alerts[:failed]&.count.to_i,
              image_metrics: processed_image_metrics,
              raw_alerts: raw_alerts,
              raw_regions: raw_regions,
            }
          )
        end

        # Explicitly override #to_h here because this method response object contains PII.
        # This method is used to determine what from this response gets written to events.log.
        # #to_h is defined on the super class and should not include any parts of the response that
        # contain PII. This method is here as a safeguard in case that changes.
        def to_h
          {
            success: success?,
            errors: errors,
            exception: exception,
            billed: result_code.billed,
          }.merge(response_info)
        end

        # @return [DocAuth::Acuant::ResultCode::ResultCode]
        def result_code
          IdentityDocAuth::Acuant::ResultCodes.from_int(parsed_response_body['Result'])
        end

        def pii_from_doc
          IdentityDocAuth::Acuant::PiiFromDoc.new(parsed_response_body).call
        end

        private

        attr_reader :http_response

        def response_info
          @response_info ||= create_response_info
        end

        def create_response_info
          alerts = processed_alerts

          {
            vendor: 'Acuant',
            doc_auth_result: result_code.name,
            processed_alerts: alerts,
            alert_failure_count: alerts[:failed]&.count.to_i,
            image_metrics: processed_image_metrics,
            raw_alerts: raw_alerts,
            raw_regions: raw_regions,
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
          @regions_by_id ||= raw_regions.index_by { |region| region["Id"] }
        end

        def raw_images_data
          parsed_response_body['Images'] || []
        end

        def processed_alerts
          @processed_alerts ||= process_raw_alerts(raw_alerts)
        end

        def processed_image_metrics
          @image_metrics ||= raw_images_data.index_by do |image|
            image.delete('Uri')
            get_image_side_name(image['Side'])
          end
        end

        def successful_result?
          passed_result? || attention_with_barcode?
        end

        def passed_result?
          result_code == IdentityDocAuth::Acuant::ResultCodes::PASSED
        end

        def attention_with_barcode?
          return false unless result_code == IdentityDocAuth::Acuant::ResultCodes::ATTENTION

          raw_alerts.all? do |alert|
            alert_result_code = IdentityDocAuth::Acuant::ResultCodes.from_int(alert['Result'])

            alert_result_code == IdentityDocAuth::Acuant::ResultCodes::PASSED ||
              (alert_result_code == IdentityDocAuth::Acuant::ResultCodes::ATTENTION &&
               alert['Key'] == BARCODE_COULD_NOT_BE_READ_ERROR)
          end
        end

        def get_image_side_name(side_number)
          side_number == 0 ? :front : :back
        end

        def get_image_info(image_id)
          @images_by_id ||= raw_images_data.index_by { |image| image["Id"] }

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
            result_code = IdentityDocAuth::Acuant::ResultCodes.from_int(raw_alert['Result'])

            new_alert = {
              name: raw_alert['Key'],
              result: result_code.name
            }

            new_alert.merge!(get_region_info(region_refs)) if region_refs.present?

            if result_code != IdentityDocAuth::Acuant::ResultCodes::PASSED
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
