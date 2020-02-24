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
    Identity.create(user_id: 3, service_provider: issuer, uuid: 'foo3', verified_at: Time.now)
    result = [{ issuer: issuer, total: 3, ial1_total: 2, ial2_total: 1}].to_json

    expect(subject.call).to eq(result)
  end
end
