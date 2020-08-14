require 'rails_helper'

describe Reports::IaaBillingReport do
  subject { described_class.new }

  let(:issuer) { 'foo' }
  let(:issuer2) { 'foo2' }
  let(:issuer3) { 'foo3' }
  let(:iaa) { 'iaa' }
  let(:results_for_1_iaa) do
    [
      {
        'iaa': 'iaa',
        'iaa_start_date': '2019-12-15',
        'iaa_end_date': '2020-07-15',
        'ial2_active_count': 0,
        'auth_counts':
          [
            {
              'issuer': 'foo',
              'ial': 1,
              'count': 0,
            },
            {
              'issuer': 'foo',
              'ial': 2,
              'count': 0,
            },
            {
              'issuer': 'foo2',
              'ial': 1,
              'count': 0,
            },
            {
              'issuer': 'foo2',
              'ial': 2,
              'count': 0,
            },
          ],
      },
    ]
  end
  let(:now) { Time.zone.parse('2020-06-15') }

  before do
    ServiceProvider.delete_all
  end

  it 'works with no SPs' do
    expect(subject.call).to eq([].to_json)
  end

  it 'ignores sps without an IAA' do
    ServiceProvider.create(issuer: issuer, friendly_name: issuer, ial: 1)

    expect(subject.call).to eq([].to_json)
  end

  it 'rolls up 2 issuers in a single IAA' do
    ServiceProvider.create(issuer: issuer, friendly_name: issuer, ial: 1, iaa: iaa,
                           iaa_start_date: now - 6.months, iaa_end_date: now + 1.month)
    ServiceProvider.create(issuer: issuer2, friendly_name: issuer2, ial: 2, iaa: iaa,
                           iaa_start_date: now - 6.months, iaa_end_date: now + 1.month)

    expect(subject.call).to eq(results_for_1_iaa.to_json)
  end
end
