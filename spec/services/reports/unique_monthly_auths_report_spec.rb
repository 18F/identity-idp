require 'rails_helper'

describe Reports::UniqueMonthlyAuthsReport do
  subject { described_class.new }

  let(:issuer) { 'foo' }
  let(:year_month) { '201901' }

  it 'is empty' do
    expect(subject.call).to eq('[]')
  end

  it 'returns 1 unique despite the count for the user being 7' do
    MonthlyAuthCount.create(issuer: 'foo', year_month: '201901', user_id: 2, auth_count: 7)
    result = [{ issuer: 'foo', year_month: '201901', total: 1 }].to_json

    expect(subject.call).to eq(result)
  end
end
