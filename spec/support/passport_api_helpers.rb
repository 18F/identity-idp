module PassportApiHelpers
  def stub_health_check_endpoints
    allow(IdentityConfig.store).to receive(:dos_passport_healthcheck_endpoint)
      .and_return(composite_health_check_endpoint)

    allow(IdentityConfig.store).to receive(:dos_passport_composite_healthcheck_endpoint)
      .and_return(health_check_endpoint)
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
