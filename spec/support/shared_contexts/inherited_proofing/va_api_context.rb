RSpec.shared_context 'va_api_context' do
  # Sample mocked API call:
  # stub_request(:get, request_uri).
  #   with(headers: request_headers).
  #   to_return(status: 200, body: '{}', headers: {})

  let(:auth_code) { 'mocked-auth-code-for-testing' }
  let(:private_key) { private_key_from_store_or(file_name: 'empty.key') }
  let(:payload) { { inherited_proofing_auth: auth_code, exp: 1.day.from_now.to_i } }
  let(:jwt_token) { JWT.encode(payload, private_key, 'RS256') }
  let(:request_uri) {
    "#{Idv::InheritedProofing::Va::Service::BASE_URI}/inherited_proofing/user_attributes"
  }
  let(:request_headers) { { Authorization: "Bearer #{jwt_token}" } }
end
