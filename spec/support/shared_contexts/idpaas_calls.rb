shared_context 'idpaas_calls' do
  let(:path) { '/user/a-token-string' }
  let(:url) { Figaro.env.idv_url + path }
  let(:uri) { URI.parse(url) }
  let(:request) { IdpPostRequest.new(path) }
  let(:response) { request.response }
end
