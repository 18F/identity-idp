module ArcgisApiHelper
  def stub_request_suggestions
    stub_request(:get, %r{/suggest}).to_return(
      status: 200, body: ArcgisApi::Mock::Fixtures.request_suggestions_response,
      headers: { content_type: 'application/json;charset=UTF-8' }
    )
  end

  def stub_request_suggestions_error
    stub_request(:get, %r{/suggest}).to_return(
      status: 200, body: ArcgisApi::Mock::Fixtures.request_suggestions_error,
      headers: { content_type: 'application/json;charset=UTF-8' }
    )
  end

  def stub_request_suggestions_error_html
    stub_request(:get, %r{/suggest}).to_return(
      status: 400, body: ArcgisApi::Mock::Fixtures.request_suggestions_error_html,
    )
  end
end
