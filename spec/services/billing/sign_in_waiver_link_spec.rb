require 'rails_helper'

RSpec.describe Billing::SignInWaiverLink do
  let(:access_token) { SecureRandom.urlsafe_base64 }

  before do
    allow(IdentityConfig.store).to receive(:token_exchange_billing_waiver_cache_seconds)
      .and_return(3600)
  end

  it 'stores the sign-in row id under the digest of the access token, for an hour' do
    described_class.write(access_token:, sp_return_log_id: 42)

    expect(described_class.read(access_token:)).to eq(42)
    key = described_class::KEY_PREFIX + Digest::SHA256.hexdigest(access_token)
    REDIS_POOL.with do |client|
      expect(client.ttl(key)).to be_between(3590, 3600)
      expect(client.keys('*')).not_to include(a_string_including(access_token))
    end
  end

  it 'is nil for a token with no entry' do
    expect(described_class.read(access_token: 'other')).to be_nil
    expect(described_class.read(access_token: nil)).to be_nil
  end

  it 'writes nothing without a token or a row' do
    described_class.write(access_token: nil, sp_return_log_id: 42)
    described_class.write(access_token:, sp_return_log_id: nil)

    expect(described_class.read(access_token:)).to be_nil
  end
end
