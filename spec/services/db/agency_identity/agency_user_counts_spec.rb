require 'rails_helper'

describe Db::AgencyIdentity::AgencyUserCounts do
  subject { described_class }

  let(:agency) { 'USDS' }

  it 'is empty' do
    expect(subject.call.ntuples).to eq(0)
  end

  it 'returns the total user counts per agency' do
    Agency.create(id: 3, name: 'USDS') unless Agency.find_by(id: 3)
    AgencyIdentity.create(user_id: 1, agency_id: 3, uuid: 'foo1')
    AgencyIdentity.create(user_id: 2, agency_id: 3, uuid: 'foo2')

    result = { agency: agency, total: 2 }.to_json

    expect(subject.call.ntuples).to eq(1)
    expect(subject.call[0].to_json).to eq(result)
  end
end
