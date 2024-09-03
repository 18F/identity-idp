# frozen_string_literal: true

module UspsInPersonProofing
  module Mock
    class Fixtures
      def self.internal_server_error_response
        load_response_fixture('internal_server_error_response.json')
      end

      def self.request_expired_token_response
        load_response_fixture('request_expired_token_response.json')
      end

      def self.request_token_response
        load_response_fixture('request_token_response.json')
      end

      def self.request_facilities_response
        load_response_fixture('request_facilities_response.json')
      end

      def self.request_enhanced_ipp_facilities_response
        load_response_fixture('request_enhanced_ipp_facilities_response.json')
      end

      def self.request_facilities_response_with_unordered_distance
        load_response_fixture('request_facilities_response_with_unordered_distance.json')
      end

      def self.request_facilities_response_with_duplicates
        load_response_fixture('request_facilities_response_with_duplicates.json')
      end

      def self.request_facilities_response_with_sponsor_error
        load_response_fixture('request_facilities_response_with_sponsor_error.json')
      end

      def self.request_show_usps_location_response
        load_response_fixture('request_show_usps_location_response.json')
      end

      def self.enrollment_selected_location_details
        load_response_fixture('enrollment_selected_location_details.json')
      end

      def self.request_enroll_response
        load_response_fixture('request_enroll_response.json')
      end

      def self.request_enroll_response_enhanced_ipp
        load_response_fixture('request_enroll_response_enhanced_ipp.json')
      end

      def self.request_enroll_bad_request_response
        load_response_fixture('request_enroll_failed_response.json')
      end

      def self.request_enroll_bad_sponsor_id_request_response
        load_response_fixture('request_enroll_bad_sponsor_id_response.json')
      end

      def self.request_enroll_invalid_response
        load_response_fixture('request_enroll_invalid_response.json')
      end

      def self.request_failed_proofing_results_response
        load_response_fixture('request_failed_proofing_results_response.json')
      end

      def self.request_failed_suspected_fraud_proofing_results_response
        load_response_fixture('request_failed_suspected_fraud_proofing_results_response.json')
      end

      def self.request_passed_proofing_unsupported_id_results_response
        load_response_fixture('request_passed_proofing_unsupported_id_results_response.json')
      end

      def self.request_passed_proofing_secondary_id_type_results_response
        load_response_fixture('request_passed_proofing_secondary_id_type_results_response.json')
      end

      def self.request_passed_proofing_supported_secondary_id_type_results_response
        load_response_fixture(
          'request_passed_proofing_supported_secondary_id_type_results_response.json',
        )
      end

      def self.request_passed_proofing_secondary_id_type_results_response_ial_2
        load_response_fixture(
          'request_passed_proofing_secondary_id_type_results_response_ial_2.json',
        )
      end

      def self.request_expired_enhanced_ipp_results_response
        load_response_fixture('request_expired_enhanced_ipp_results_response.json')
      end

      def self.request_expired_id_ipp_results_response
        load_response_fixture('request_expired_id_ipp_results_response.json')
      end

      def self.request_unexpected_expired_proofing_results_response
        load_response_fixture('request_unexpected_expired_proofing_results_response.json')
      end

      def self.request_unexpected_invalid_applicant_response
        load_response_fixture('request_unexpected_invalid_applicant_response.json')
      end

      def self.request_unexpected_invalid_enrollment_code_response
        load_response_fixture('request_unexpected_invalid_enrollment_code_response.json')
      end

      def self.request_no_post_office_proofing_results_response
        load_response_fixture('request_no_post_office_proofing_results_response.json')
      end

      def self.request_passed_proofing_results_response
        load_response_fixture('request_passed_proofing_results_response.json')
      end

      def self.request_passed_proofing_unsupported_status_results_response
        load_response_fixture('request_passed_proofing_unsupported_status_results_response.json')
      end

      def self.request_in_progress_proofing_results_response
        load_response_fixture('request_in_progress_proofing_results_response.json')
      end

      def self.load_response_fixture(filename)
        path = File.join(
          File.dirname(__FILE__),
          'responses',
          filename,
        )
        File.read(path)
      end
    end
  end
end
