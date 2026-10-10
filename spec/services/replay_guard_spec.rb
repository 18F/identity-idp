require 'rails_helper'

RSpec.describe ReplayGuard do
  # Redis is shared across examples, so every example presents its own values.
  let(:namespace) { 'dpop:jti' }
  let(:scope) { SecureRandom.hex }
  let(:value) { SecureRandom.hex }

  def first_use?(value: self.value, scope: self.scope, namespace: self.namespace, ttl: 60)
    described_class.first_use?(namespace:, scope:, value:, ttl:)
  end

  it 'accepts a value once and refuses it afterwards' do
    expect(first_use?).to eq(true)
    expect(first_use?).to eq(false)
  end

  it 'keeps the value for the given ttl' do
    first_use?(ttl: 120)
    key = described_class.key(namespace:, scope:, value:)

    expect(REDIS_POOL.with { |client| client.ttl(key) }).to be_between(115, 120)
  end

  it 'records the same value separately per presenter and per namespace' do
    expect(first_use?).to eq(true)
    expect(first_use?(scope: SecureRandom.hex)).to eq(true)
    expect(first_use?(namespace: 'client-assertion:jti')).to eq(true)
    expect(first_use?).to eq(false)
  end

  it 'refuses a value that is not a non-empty string' do
    expect(first_use?(value: nil)).to eq(false)
    expect(first_use?(value: '')).to eq(false)
    expect(first_use?(value: 1)).to eq(false)
  end
end
