require 'rails_helper'

describe Db::AgencyIdentity::AgencyUserCounts do
  subject { described_class }

  let(:agency) { create(:agency) }

  it 'is empty' do
    expect(subject.call.ntuples).to eq(0)
  end

  it 'returns the total user counts per agency' do
    AgencyIdentity.create(user_id: 1, agency_id: agency.id, uuid: 'foo1')
    AgencyIdentity.create(user_id: 2, agency_id: agency.id, uuid: 'foo2')

    result = { agency: agency.name, total: 2 }.to_json

    expect(subject.call.ntuples).to eq(1)
    expect(subject.call[0].to_json).to eq(result)
  end
end
