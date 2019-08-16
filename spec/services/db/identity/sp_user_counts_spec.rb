require 'rails_helper'

describe Db::Identity::SpUserCounts do
  subject { described_class }

  let(:issuer) { 'foo' }

  it 'is empty' do
    expect(subject.call.ntuples).to eq(0)
  end

  it 'returns the total user counts per sp' do
    Identity.create(user_id: 1, service_provider: issuer, uuid: 'foo1')
    Identity.create(user_id: 2, service_provider: issuer, uuid: 'foo2')

    result = { issuer: issuer, total: 2 }.to_json

    expect(subject.call.ntuples).to eq(1)
    expect(subject.call[0].to_json).to eq(result)
  end
end
