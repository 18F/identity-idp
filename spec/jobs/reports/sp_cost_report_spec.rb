require 'rails_helper'

describe Reports::SpCostReport do
  subject { described_class.new }

  let(:issuer1) { 'issuer1' }
  let(:app_id1) { 'app_id1' }
  let(:issuer2) { 'issuer2' }
  let(:app_id2) { 'app_id2' }

  it 'is empty' do
    expect(subject.perform(Time.zone.today)).to eq('[]')
  end

  it 'totals the cost per sp' do
    ::SpCost.create(issuer: issuer1, ial: 1, agency_id: 2, cost_type: 'foo')
    ::SpCost.create(issuer: issuer1, ial: 1, agency_id: 2, cost_type: 'foo')
    ::SpCost.create(issuer: issuer2, ial: 2, agency_id: 3, cost_type: 'bar')
    ServiceProvider.create(issuer: issuer1, friendly_name: issuer1, app_id: app_id1)
    ServiceProvider.create(issuer: issuer2, friendly_name: issuer2, app_id: app_id2)
    expect(JSON.parse(subject.perform(Time.zone.today))).to eq(
      [{
        'issuer' => 'issuer1',
        'ial' => 1,
        'app_id' => app_id1,
        'cost_type' => 'foo',
        'count' => 2,
      },
       {
         'issuer' => 'issuer2',
         'ial' => 2,
         'app_id' => app_id2,
         'cost_type' => 'bar',
         'count' => 1,
       }],
    )
  end
end
