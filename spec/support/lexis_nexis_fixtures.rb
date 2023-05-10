require 'rails_helper'

module LexisNexisFixtures
  class << self
    def example_config
      Proofing::LexisNexis::Config.new(
        base_url: 'https://example.com',
        request_mode: 'testing',
        account_id: 'test_account',
        username: 'test_username',
        password: 'test_password',
        hmac_key_id: 'test_hmac_key_id',
        hmac_secret_key: 'test_hmac_secret_key',
        instant_verify_workflow: 'gsa2.chk32.test.wf',
        phone_finder_workflow: 'customers.gsa2.phonefinder.workflow',
      )
    end

    def example_ddp_config
      Proofing::LexisNexis::Config.new(
        api_key: 'test_api_key',
        base_url: 'https://example.com',
        org_id: 'test_org_id',
      )
    end

    def ddp_request_json
      raw = read_fixture_file_at_path('ddp/request.json')
      JSON.parse(raw).to_json
    end

    def ddp_success_response_json
      raw = read_fixture_file_at_path('ddp/successful_response.json')
      JSON.parse(raw).to_json
    end

    def ddp_success_redacted_response_json
      raw = read_fixture_file_at_path('ddp/successful_redacted_response.json')
      JSON.parse(raw).to_json
    end

    def ddp_failure_response_json
      raw = read_fixture_file_at_path('ddp/failed_response.json')
      JSON.parse(raw).to_json
    end

    def ddp_error_response_json
      raw = read_fixture_file_at_path('ddp/error_response.json')
      JSON.parse(raw).to_json
    end

    def ddp_unexpected_review_status
      'unexpected_review_status_that_causes_problems'
    end

    def ddp_unexpected_review_status_response_json
      raw = read_fixture_file_at_path('ddp/successful_response.json')
      JSON.parse(raw).merge(
        review_status: ddp_unexpected_review_status,
      ).to_json
    end

    def instant_verify_request_json
      raw = read_fixture_file_at_path('instant_verify/request.json')
      JSON.parse(raw).to_json
    end

    def instant_verify_success_response_json
      raw = read_fixture_file_at_path('instant_verify/successful_response.json')
      JSON.parse(raw).to_json
    end

    def instant_verify_error_response_json
      raw = read_fixture_file_at_path('instant_verify/error_response.json')
      JSON.parse(raw).to_json
    end

    def instant_verify_identity_not_found_response_json
      raw = read_fixture_file_at_path('instant_verify/identity_not_found_response.json')
      JSON.parse(raw).to_json
    end

    def instant_verify_date_of_birth_fail_response_json
      raw = read_fixture_file_at_path('instant_verify/date_of_birth_failure_response.json')
      JSON.parse(raw).to_json
    end

    def instant_verify_address_fail_response_json
      raw = read_fixture_file_at_path('instant_verify/address_failure_response.json')
      JSON.parse(raw).to_json
    end

    def instant_verify_date_of_birth_and_address_fail_response_json
      raw = read_fixture_file_at_path(
        'instant_verify/date_of_birth_and_address_failure_response.json',
      )
      JSON.parse(raw).to_json
    end

    def instant_verify_drivers_license_failure_response_json
      raw = read_fixture_file_at_path(
        'instant_verify/drivers_license_failure_response.json',
      )
      JSON.parse(raw).to_json
    end

    def instant_verify_drivers_license_info_missing_response_json
      raw = read_fixture_file_at_path(
        'instant_verify/drivers_license_info_missing_response.json',
      )
      JSON.parse(raw).to_json
    end

    def phone_finder_request_json
      raw = read_fixture_file_at_path('phone_finder/request.json')
      JSON.parse(raw).to_json
    end

    def phone_finder_rdp1_success_response_json
      raw = read_fixture_file_at_path('phone_finder/rdp1_response.json')
      JSON.parse(raw).to_json
    end

    def phone_finder_rdp2_success_response_json
      raw = read_fixture_file_at_path('phone_finder/rdp2_response.json')
      JSON.parse(raw).to_json
    end

    def phone_finder_rdp1_fail_response_json
      raw = read_fixture_file_at_path('phone_finder/rdp1_fail_response.json')
      JSON.parse(raw).to_json
    end

    def phone_finder_rdp2_fail_response_json
      raw = read_fixture_file_at_path('phone_finder/rdp2_fail_response.json')
      JSON.parse(raw).to_json
    end

    def communications_error
      read_fixture_file_at_path('true_id/communications_error.json')
    end

    def internal_application_error
      read_fixture_file_at_path('true_id/internal_application_error.json')
    end

    def true_id_barcode_read_attention
      read_fixture_file_at_path('true_id/true_id_response_attention_barcode.json')
    end

    def true_id_failure_empty
      read_fixture_file_at_path('true_id/true_id_response_failure_empty.json')
    end

    def true_id_response_success
      read_fixture_file_at_path('true_id/true_id_response_success.json')
    end

    def true_id_response_success_2
      read_fixture_file_at_path('true_id/true_id_response_success_2.json')
    end

    def true_id_response_failure_no_liveness
      read_fixture_file_at_path('true_id/true_id_response_failure_no_liveness.json')
    end

    def true_id_response_failure_with_liveness
      read_fixture_file_at_path('true_id/true_id_response_failure_with_liveness.json')
    end

    def true_id_response_failure_with_all_failures
      read_fixture_file_at_path('true_id/true_id_response_failure_with_all_failures.json')
    end

    def true_id_response_malformed
      read_fixture_file_at_path('true_id/true_id_response_malformed.json')
    end

    def true_id_response_failure_no_liveness_low_dpi
      read_fixture_file_at_path('true_id/true_id_response_failure_no_liveness_low_dpi.json')
    end

    private

    def read_fixture_file_at_path(filepath)
      expanded_path = Rails.root.join(
        'spec',
        'fixtures',
        'proofing',
        'lexis_nexis',
        filepath,
      )
      File.read(expanded_path)
    end
  end
end
