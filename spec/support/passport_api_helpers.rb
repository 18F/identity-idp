module PassportApiHelpers
  def successful_api_health_check_body = {
    name: 'Passport Match Process API',
    status: 'Up',
    environment: 'dev-share',
    comments: 'Ok',
  }

  def stub_api_up
    stub_request(:get, health_check_endpoint)
      .to_return_json(
        body: successful_api_health_check_body,
      )
  end
end
