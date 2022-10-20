module ArcgisApiHelper
  def stub_request_suggestions
    stub_request(:get, %r{/suggest}).to_return(
      status: 200, body: ArcgisApi::Mock::Fixtures.request_suggestions_response,
    )
  end
end
