require 'rails_helper'

RSpec.describe Reports::SpActiveUsersReport do
  subject { Reports::SpActiveUsersReport.new }

  let(:app_id) { 'app' }
  let(:sp) { create(:service_provider, app_id:) }
  let(:sp2) { create(:service_provider) }
  let(:issuer) { sp.issuer }
  let(:issuer2) { sp2.issuer }
  let(:user1) { create(:user) }
  let(:user2) { create(:user) }
  let(:user3) { create(:user) }
  let(:user4) { create(:user) }
  let(:user5) { create(:user) }

  it 'has overall data' do
    report = JSON.parse(subject.perform(Time.zone.today), symbolize_names: true)

    expect(report).to eq(
      [
        {
          issuer: nil,
          app_id: nil,
          total_ial1_active: 0,
          total_ial2_active: 0,
        },
      ],
    )
  end

  it 'returns total active user counts per sp broken down by ial1 and ial2' do
    job_date = Date.new(2022, 1, 1)
    authenticated_time = job_date.noon
    ServiceProviderIdentity.create(
      user_id: user1.id, service_provider: issuer, uuid: 'foo1',
      last_ial1_authenticated_at: authenticated_time, last_ial2_authenticated_at: authenticated_time
    )
    ServiceProviderIdentity.create(
      user_id: user2.id, service_provider: issuer, uuid: 'foo2',
      last_ial1_authenticated_at: authenticated_time
    )
    ServiceProviderIdentity.create(
      user_id: user3.id, service_provider: issuer, uuid: 'foo3',
      last_ial2_authenticated_at: authenticated_time
    )
    ServiceProviderIdentity.create(
      user_id: user4.id, service_provider: issuer, uuid: 'foo4',
      last_ial2_authenticated_at: authenticated_time
    )
    result = [
      {
        issuer: issuer,
        app_id: app_id,
        total_ial1_active: 1,
        total_ial2_active: 3,
      },
      {
        issuer: nil,
        app_id: nil,
        total_ial1_active: 1,
        total_ial2_active: 3,
      },
    ]

    report = JSON.parse(subject.perform(job_date), symbolize_names: true)

    expect(report).to match_array(result)
  end

  it 'when Oct 1, returns total active user counts per sp by ial1 and ial2 for last fiscal year' do
    # run date is from 2019-10-01 to 2020-09-30
    job_date = Date.new(2020, 10, 1)
    job_date_range = subject.reporting_range(job_date)
    beginning_of_last_fiscal_year = job_date_range.first
    end_of_last_fiscal_year = job_date_range.last
    middle_of_last_fiscal_year = job_date.change(year: 2020, month: 1, day: 31).end_of_day

    beginning_of_current_fiscal_year = job_date.beginning_of_day
    current_fiscal_year = job_date.change(hour: 12, minute: 30)

    ServiceProviderIdentity.create(
      user_id: user1.id, service_provider: issuer, uuid: 'foo1',
      last_ial1_authenticated_at: beginning_of_last_fiscal_year,
      last_ial2_authenticated_at: beginning_of_last_fiscal_year
    )
    ServiceProviderIdentity.create(
      user_id: user2.id, service_provider: issuer, uuid: 'foo2',
      last_ial1_authenticated_at: end_of_last_fiscal_year,
      last_ial2_authenticated_at: end_of_last_fiscal_year
    )
    ServiceProviderIdentity.create(
      user_id: user3.id, service_provider: issuer, uuid: 'foo3',
      last_ial2_authenticated_at: middle_of_last_fiscal_year
    )
    ServiceProviderIdentity.create(
      user_id: user4.id, service_provider: issuer, uuid: 'foo4',
      last_ial2_authenticated_at: beginning_of_current_fiscal_year
    )

    ServiceProviderIdentity.create(
      user_id: user5.id, service_provider: issuer, uuid: 'foo5',
      last_ial2_authenticated_at: current_fiscal_year
    )

    result = [
      {
        issuer:,
        app_id:,
        total_ial1_active: 0,
        total_ial2_active: 3,
      },
      {
        issuer: nil,
        app_id: nil,
        total_ial1_active: 0,
        total_ial2_active: 3,
      },
    ]

    report = JSON.parse(subject.perform(job_date), symbolize_names: true)

    expect(report).to match_array(result)
  end

  describe '#reporting_range' do
    it 'returns entire last fiscal year when it is October 1st' do
      job_date = Date.new(2022, 10, 1)
      beginning = Date.new(2021, 10, 1).beginning_of_day
      ending = Date.new(2022, 9, 30).end_of_day
      expect(subject.reporting_range(job_date)).to eq(beginning..ending)
    end

    it 'returns current fiscal year until end of day when prior to Oct 1st' do
      job_date = Date.new(2022, 5, 1)
      beginning = Date.new(2021, 10, 1).beginning_of_day
      ending = job_date.end_of_day
      expect(subject.reporting_range(job_date)).to eq(beginning..ending)
    end

    it 'returns current fiscal year until end of day when after to Oct 1st' do
      job_date = Date.new(2022, 11, 1)
      beginning = Date.new(2022, 10, 1).beginning_of_day
      ending = job_date.end_of_day
      expect(subject.reporting_range(job_date)).to eq(beginning..ending)
    end
  end
end
