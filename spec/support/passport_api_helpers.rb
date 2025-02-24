module PassportApiHelpers
  module Helpers
    def stub_health_check_settings
      allow(IdentityConfig.store).to receive(:dos_passport_healthcheck_endpoint)
        .and_return(composite_health_check_endpoint)

      allow(IdentityConfig.store).to receive(:dos_passport_composite_healthcheck_endpoint)
        .and_return(health_check_endpoint)
    end

    def stub_health_check_endpoints
      stub_request(:get, health_check_endpoint)
        .to_return_json(body: successful_api_health_check_body)

      stub_request(:get, composite_health_check_endpoint)
        .to_return_json(body: successful_api_health_check_body)
    end

    def health_check_endpoint
      'https://dos-health-check-endpoint.test.org'
    end    

    def composite_health_check_endpoint
      'https://composite-health-check-endpoint.test.org'
    end    

    def successful_api_health_check_body
      {
        name: 'Passport Match Process API',
        status: 'Up',
        environment: 'dev-share',
        comments: 'Ok',
      }
    end
  end

  def self.included(base)
    base.extend(Helpers)
    base.include(Helpers)
  end
end
