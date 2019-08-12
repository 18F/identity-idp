require 'rails_helper'

describe Reports::TotalMonthlyAuthsReport do
  subject { described_class.new }

  let(:issuer) { 'foo' }
  let(:year_month) { '201901' }

  it 'is empty' do
    expect(subject.call).to eq('[]')
  end

  it 'returns the total monthly auths' do
    MonthlyAuthCount.create(issuer: 'foo', year_month: '201901', user_id: 2, auth_count: 7)
    MonthlyAuthCount.create(issuer: 'foo', year_month: '201901', user_id: 3, auth_count: 3)
    result = [{ issuer: 'foo', year_month: '201901', total: 10 }].to_json

    expect(subject.call).to eq(result)
  end
end
