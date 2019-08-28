require 'rails_helper'

describe Db::MonthlyAuthCount::UniqueMonthlyAuthCounts do
  subject { described_class }

  let(:issuer) { 'foo' }
  let(:year_month) { '201901' }

  it 'is empty' do
    expect(subject.call.ntuples).to eq(0)
  end

  it 'returns 1 unique despite the count for the user being 7' do
    MonthlyAuthCount.create(issuer: issuer, year_month: year_month, user_id: 2, auth_count: 7)
    result = { issuer: issuer, year_month: year_month, total: 1 }.to_json

    expect(subject.call.ntuples).to eq(1)
    expect(subject.call[0].to_json).to eq(result)
  end
end
