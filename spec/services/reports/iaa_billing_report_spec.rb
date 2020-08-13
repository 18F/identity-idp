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
        'auth_counts': [
          {
            'issuer': 'http://test.host',
            'ial': 1,
            'count': 0,
          },
          {
            'issuer': 'http://test.host',
            'ial': 2,
            'count': 0,
          },
        ],
      },
    ]
  end

  it 'works' do
    expect(subject.call).to eq(results.to_json)
  end
end
