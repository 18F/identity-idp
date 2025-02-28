module PassportApiHelpers
  module Helpers
    def stub_health_check_settings
      allow(IdentityConfig.store).to receive(:dos_passport_healthcheck_endpoint)
        .and_return(general_health_check_endpoint)

      allow(IdentityConfig.store).to receive(:dos_passport_composite_healthcheck_endpoint)
        .and_return(composite_health_check_endpoint)
    end

    def stub_health_check_endpoints
      stub_request(:get, general_health_check_endpoint)
        .to_return_json(body: successful_api_general_health_check_body)

      stub_request(:get, composite_health_check_endpoint)
        .to_return_json(body: successful_api_composite_health_check_body)
    end

    def general_health_check_endpoint
      'https://dos-health-check-endpoint.test'
    end

    def composite_health_check_endpoint
      'https://composite-health-check-endpoint.test'
    end

    def successful_api_general_health_check_body
      JSON.parse(
        File.read(
          Rails.root.join(
            'spec', 'fixtures', 'dos', 'healthcheck',
            'general_health_success.json'
          ),
        ),
      )
    end

    def successful_api_composite_health_check_body
      JSON.parse(
        File.read(
          Rails.root.join(
            'spec', 'fixtures', 'dos', 'healthcheck',
            'composite_health_success.json'
          ),
        ),
      )
    end
 end

  def self.included(base)
    base.extend(Helpers)
    base.include(Helpers)
  end
end
