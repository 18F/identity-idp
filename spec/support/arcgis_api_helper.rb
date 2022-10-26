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

  def stub_request_candidates_response
    stub_request(:get, %r{/findAddressCandidates}).to_return(
      status: 200, body: ArcgisApi::Mock::Fixtures.request_candidates_response,
      headers: { content_type: 'application/json;charset=UTF-8' }
    )
  end

  def stub_request_candidates_empty_response
    stub_request(:get, %r{/findAddressCandidates}).to_return(
      status: 200, body: ArcgisApi::Mock::Fixtures.request_candidates_empty_response,
      headers: { content_type: 'application/json;charset=UTF-8' }
    )
  end

  def stub_request_candidates_error
    stub_request(:get, %r{/findAddressCandidates}).to_return(
      status: 200, body: ArcgisApi::Mock::Fixtures.request_candidates_error,
      headers: { content_type: 'application/json;charset=UTF-8' }
    )
  end

  def stub_generate_token_response(expires_at = 1.hour.from_now.to_i)
    stub_request(:post, %r{/generateToken}).to_return(
      status: 200, body: {
        token: 'abc123',
        expires: expires_at,
        ssl: true,
      }.to_json,
      headers: { content_type: 'application/json;charset=UTF-8' }
    )
  end

  def stub_invalid_token_response
    stub_request(:get, %r{/suggest}).to_return(
      status: 200, body: {
        error: {
          code: 498,
          message: 'Invalid Token',
          details: [],
        },
      }.to_json,
      headers: { content_type: 'application/json;charset=UTF-8' }
    )
  end
end
