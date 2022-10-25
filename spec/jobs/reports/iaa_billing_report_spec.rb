require 'rails_helper'

describe Reports::IaaBillingReport do
  subject { described_class.new }

  let(:issuer) { 'foo' }
  let(:issuer2) { 'foo2' }
  let(:issuer3) { 'foo3' }
  let(:iaa) { 'iaa' }
  let(:iaa2) { 'iaa2' }
  let(:iaa_start_date1_str) { '2020-02-01' }
  let(:iaa_end_date1_str) { '2021-02-01' }
  let(:iaa_start_date2_str) { '2020-05-01' }
  let(:iaa_end_date2_str) { '2021-05-01' }
  let(:iaa_start_date1) { Time.zone.parse(iaa_start_date1_str) }
  let(:iaa_end_date1) { Time.zone.parse(iaa_end_date1_str) }
  let(:iaa_start_date2) { Time.zone.parse(iaa_start_date2_str) }
  let(:iaa_end_date2) { Time.zone.parse(iaa_end_date2_str) }

  let(:results_for_1_iaa) do
    [
      {
        iaa: 'iaa',
        iaa_start_date: iaa_start_date1_str,
        iaa_end_date: iaa_end_date1_str,
        ial2_active_count: 0,
        auth_counts:
          [
            {
              issuer: 'foo',
              ial: 1,
              count: 0,
            },
            {
              issuer: 'foo',
              ial: 2,
              count: 0,
            },
            {
              issuer: 'foo2',
              ial: 1,
              count: 0,
            },
            {
              issuer: 'foo2',
              ial: 2,
              count: 0,
            },
          ],
      },
    ]
  end
  let(:results_for_2_iaas_1) do
    {
      iaa: 'iaa',
      iaa_start_date: iaa_start_date1_str,
      iaa_end_date: iaa_end_date1_str,
      ial2_active_count: 1,
      auth_counts:
      [
        {
          issuer: 'foo',
          ial: 1,
          count: 7,
        },
        {
          issuer: 'foo',
          ial: 2,
          count: 0,
        },
      ],
    }
  end
  let(:results_for_2_iaas_2) do
    {
      iaa: 'iaa2',
      iaa_start_date: iaa_start_date2_str,
      iaa_end_date: iaa_end_date2_str,
      ial2_active_count: 1,
      auth_counts:
        [
          {
            issuer: 'foo2',
            ial: 1,
            count: 0,
          },
          {
            issuer: 'foo2',
            ial: 2,
            count: 3,
          },
          {
            issuer: 'foo3',
            ial: 1,
            count: 0,
          },
          {
            issuer: 'foo3',
            ial: 2,
            count: 0,
          },
        ],
    }
  end

  let(:now) { Time.zone.parse('2020-06-15') }

  before do
    Agreements::IntegrationUsage.delete_all
    Agreements::Integration.delete_all
    ServiceProvider.delete_all
    travel_to(now)
  end

  it 'works with no SPs' do
    expect(subject.perform(Time.zone.today)).to eq([].to_json)
  end

  it 'ignores sps without an IAA or a start date or an end date' do
    ServiceProvider.create(issuer: issuer, friendly_name: issuer, ial: 1)
    ServiceProvider.create(
      issuer: issuer2, friendly_name: issuer2, ial: 1, iaa: iaa,
      iaa_start_date: iaa_start_date1
    )
    ServiceProvider.create(
      issuer: issuer3, friendly_name: issuer3, ial: 1, iaa: iaa2,
      iaa_end_date: iaa_end_date1
    )

    expect(subject.perform(Time.zone.today)).to eq([].to_json)
  end

  it 'rolls up 2 issuers in a single IAA' do
    ServiceProvider.create(
      issuer: issuer, friendly_name: issuer, ial: 1, iaa: iaa,
      iaa_start_date: iaa_start_date1, iaa_end_date: iaa_end_date1
    )
    ServiceProvider.create(
      issuer: issuer2, friendly_name: issuer2, ial: 2, iaa: iaa,
      iaa_start_date: iaa_start_date1, iaa_end_date: iaa_end_date1
    )

    expect(subject.perform(Time.zone.today)).to eq(results_for_1_iaa.to_json)
  end

  it 'works with multiple IAAs and issuers' do
    last_month = now.last_month
    today_year_month = now.strftime('%Y%m')

    ServiceProvider.create(
      issuer: issuer, friendly_name: issuer, ial: 1, iaa: iaa,
      iaa_start_date: iaa_start_date1, iaa_end_date: iaa_end_date1
    )
    ServiceProvider.create(
      issuer: issuer2, friendly_name: issuer2, ial: 2, iaa: iaa2,
      iaa_start_date: iaa_start_date2, iaa_end_date: iaa_end_date2
    )
    ServiceProvider.create(
      issuer: issuer3, friendly_name: issuer3, ial: 2, iaa: iaa2,
      iaa_start_date: iaa_start_date2, iaa_end_date: iaa_end_date2
    )
    ServiceProviderIdentity.create(
      user_id: 1, service_provider: issuer, uuid: 'a',
      last_ial2_authenticated_at: now - 1.hour
    )
    ServiceProviderIdentity.create(
      user_id: 2, service_provider: issuer2, uuid: 'b',
      last_ial2_authenticated_at: last_month
    )
    ServiceProviderIdentity.create(
      user_id: 3, service_provider: issuer3, uuid: 'c',
      last_ial2_authenticated_at: now - 1.hour
    )
    create(:profile, :active, :verified, user_id: 1)
    create(:profile, :active, :verified, user_id: 2)
    create(:profile, :active, :verified, user_id: 3)
    MonthlySpAuthCount.create(
      issuer: issuer, ial: 1, year_month: today_year_month, user_id: 2,
      auth_count: 7
    )
    MonthlySpAuthCount.create(
      issuer: issuer2, ial: 2, year_month: today_year_month, user_id: 3,
      auth_count: 3
    )

    tuples = subject.perform(Time.zone.today)
    expect(tuples).to include(results_for_2_iaas_1.to_json)
    expect(tuples).to include(results_for_2_iaas_2.to_json)
  end
end
