module UspsInPersonProofing
  module Mock
    class Fixtures
      def self.request_token_response
        load_response_fixture('request_token_response.json')
      end

      def self.request_facilities_response
        load_response_fixture('request_facilities_response.json')
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

      def self.request_enroll_bad_request_response
        load_response_fixture('request_enroll_failed_response.json')
      end

      def self.request_enroll_internal_failure_response
        load_response_fixture('request_enroll_internal_failure_response.json')
      end

      def self.request_enroll_invalid_response
        load_response_fixture('request_enroll_invalid_response.json')
      end

      def self.request_failed_proofing_results_response
        load_response_fixture('request_failed_proofing_results_response.json')
      end

      def self.request_passed_proofing_unsupported_id_results_response
        load_response_fixture('request_passed_proofing_unsupported_id_results_response.json')
      end

      def self.request_expired_proofing_results_response
        load_response_fixture('request_expired_proofing_results_response.json')
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

      def self.request_enrollment_code_response
        load_response_fixture('request_enrollment_code_response.json')
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
