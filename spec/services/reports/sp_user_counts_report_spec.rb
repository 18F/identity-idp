require 'rails_helper'

describe Reports::SpUserCountsReport do
  subject { described_class.new }

  let(:issuer) { 'foo' }

  it 'is empty' do
    expect(subject.call).to eq('[]')
  end

  it 'returns the total user counts per sp' do
    Identity.create(user_id: 1, service_provider: issuer, uuid: 'foo1')
    Identity.create(user_id: 2, service_provider: issuer, uuid: 'foo2')
    result = [{ issuer: issuer, total: 2 }].to_json

    expect(subject.call).to eq(result)
  end
end
