require 'rails_helper'

module LexisNexisFixtures
  class << self
    def example_config
      LexisNexis::Proofer::Config.new(
        base_url: 'https://example.com',
        request_mode: 'testing',
        account_id: 'test_account',
        username: 'test_username',
        password: 'test_password',
        instant_verify_workflow: 'customers.gsa.instant.verify.workflow',
        phone_finder_workflow: 'customers.gsa.phonefinder.workflow',
        )
    end

    def instant_verify_request_json
      raw = read_fixture_file_at_path('instant_verify/request.json')
      JSON.parse(raw).to_json
    end

    def instant_verify_success_response_json
      raw = read_fixture_file_at_path('instant_verify/successful_response.json')
      JSON.parse(raw).to_json
    end

    def instant_verify_failure_response_json
      raw = read_fixture_file_at_path('instant_verify/failed_response.json')
      JSON.parse(raw).to_json
    end

    def instant_verify_error_response_json
      raw = read_fixture_file_at_path('instant_verify/error_response.json')
      JSON.parse(raw).to_json
    end

    def instant_verify_year_of_birth_fail_response_json
      raw = read_fixture_file_at_path('instant_verify/year_of_birth_fail_response.json')
      JSON.parse(raw).to_json
    end

    def instant_verify_date_of_birth_full_fail_response_json
      raw = read_fixture_file_at_path('instant_verify/date_of_birth_full_fail_response.json')
      JSON.parse(raw).to_json
    end

    def phone_finder_request_json
      raw = read_fixture_file_at_path('phone_finder/request.json')
      JSON.parse(raw).to_json
    end

    def phone_finder_success_response_json
      raw = read_fixture_file_at_path('phone_finder/response.json')
      JSON.parse(raw).to_json
    end

    def phone_finder_fail_response_json
      raw = read_fixture_file_at_path('phone_finder/fail_response.json')
      JSON.parse(raw).to_json
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
