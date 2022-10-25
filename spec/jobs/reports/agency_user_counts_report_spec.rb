require 'rails_helper'

describe Reports::AgencyUserCountsReport do
  subject { described_class.new }

  let(:agency) { create(:agency) }

  it 'is empty' do
    expect(subject.perform(Time.zone.today)).to eq('[]')
  end

  it 'returns the total user counts per agency' do
    AgencyIdentity.create(user_id: 1, agency_id: agency.id, uuid: 'foo1')
    AgencyIdentity.create(user_id: 2, agency_id: agency.id, uuid: 'foo2')
    result = [{ agency: agency.name, total: 2 }].to_json

    expect(subject.perform(Time.zone.today)).to eq(result)
  end
end
