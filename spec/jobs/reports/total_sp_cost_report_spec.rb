require 'rails_helper'

describe Reports::TotalSpCostReport do
  subject { described_class.new }

  let(:issuer1) { 'issuer1' }
  let(:issuer2) { 'issuer2' }

  it 'is empty' do
    expect(subject.perform(Time.zone.today)).to eq('[]')
  end

  it 'totals the cost per sp' do
    ::SpCost.create(issuer: '', ial: 1, agency_id: 0, cost_type: 'foo')
    ::SpCost.create(issuer: issuer1, ial: 1, agency_id: 2, cost_type: 'foo')
    ::SpCost.create(issuer: issuer1, ial: 1, agency_id: 2, cost_type: 'foo')
    ::SpCost.create(issuer: issuer2, ial: 2, agency_id: 3, cost_type: 'bar')
    expect(JSON.parse(subject.perform(Time.zone.today))).to eq(
      [{
        'cost_type' => 'bar',
        'count' => 1,
      },
       {
         'cost_type' => 'foo',
         'count' => 3,
       }],
    )
  end
end
