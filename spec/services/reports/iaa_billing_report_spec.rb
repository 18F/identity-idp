require 'rails_helper'

describe Reports::IaaBillingReport do
  subject { described_class.new }

  let(:results) do
    [
      {
        'iaa': 'ABC123-2020',
        'iaa_start_date': '2020-01-01',
        'iaa_end_date': '2020-12-31',
        'ial2_active_count': 0,
      },
    ]
  end

  it 'is empty' do
    expect(subject.call).to eq(results.to_json)
  end
end
