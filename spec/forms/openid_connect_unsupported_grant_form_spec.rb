require 'rails_helper'

RSpec.describe OpenidConnectUnsupportedGrantForm do
  subject(:form) { described_class.new(grant_type: 'client_credentials', client_id: 'urn:x') }

  it 'fails with unsupported_grant_type and reports the client' do
    result = form.submit
    expect(result.success?).to eq(false)
    expect(result.to_h).to eq(
      success: false,
      client_id: 'urn:x',
      error_details: { grant_type: { unsupported_grant_type: true } },
      user_id: nil,
      code_digest: nil,
      ial: nil,
      code_verifier_present: false,
      service_provider_pkce: nil,
      integration_errors: nil,
    )
  end

  it 'renders the RFC 6749 error object' do
    expect(form.response).to eq(
      error: 'unsupported_grant_type',
      error_description: t('openid_connect.token.errors.unsupported_grant_type'),
    )
  end
end
