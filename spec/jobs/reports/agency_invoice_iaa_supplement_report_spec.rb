require 'rails_helper'

RSpec.describe Reports::AgencyInvoiceIaaSupplementReport do
  subject(:report) { Reports::AgencyInvoiceIaaSupplementReport.new }

  let(:partner_account1) { create(:partner_account) }
  let(:partner_account2) { create(:partner_account) }
  let(:gtc1) do
    create(
      :iaa_gtc,
      gtc_number: 'gtc1234',
      partner_account: partner_account1,
      start_date: iaa1_range.begin,
      end_date: iaa1_range.end,
    )
  end

  let(:gtc2) do
    create(
      :iaa_gtc,
      gtc_number: 'gtc5678',
      partner_account: partner_account2,
      start_date: iaa2_range.begin,
      end_date: iaa2_range.end,
    )
  end

  let(:iaa_order1) do
    build_iaa_order(order_number: 1, date_range: iaa1_range, iaa_gtc: gtc1)
  end
  let(:iaa_order2) do
    build_iaa_order(order_number: 2, date_range: iaa2_range, iaa_gtc: gtc2)
  end

  # Have to do this because of invalid check when building integration usages
  let!(:iaa_orders) do
    [
      iaa_order1,
      iaa_order2,
    ]
  end

  let!(:iaa1_sp) do
    create(
      :service_provider,
      iaa: iaa1,
      iaa_start_date: iaa1_range.begin,
      iaa_end_date: iaa1_range.end,
    )
  end

  let!(:iaa2_sp) do
    create(
      :service_provider,
      iaa: iaa2,
      iaa_start_date: iaa2_range.begin,
      iaa_end_date: iaa2_range.end,
    )
  end

  let(:integration1) do
    build_integration(issuer: iaa1_sp.issuer, partner_account: partner_account1)
  end
  let(:integration2) do
    build_integration(issuer: iaa2_sp.issuer, partner_account: partner_account2)
  end

  let(:iaa1) { 'iaa1' }
  let(:iaa1_key) { "#{gtc1.gtc_number}-#{format('%04d', iaa_order1.order_number)}" }
  let(:iaa1_range) { Date.new(2020, 4, 15)..Date.new(2021, 4, 14) }
  let(:inside_iaa1) { iaa1_range.begin + 1.day }

  let(:iaa2) { 'iaa2' }
  let(:iaa2_key) { "#{gtc2.gtc_number}-#{format('%04d', iaa_order2.order_number)}" }
  let(:iaa2_range) { Date.new(2020, 9, 1)..Date.new(2021, 8, 30) }
  let(:inside_iaa2) { iaa2_range.begin + 1.day }

  describe '#perform' do
    it 'is empty with no data' do
      expect(report.perform(Time.zone.today)).to eq('[]')
    end

    context 'with data' do
      let(:user1) { create(:user) }
      let(:user2) { create(:user) }

      before do
        iaa_order1.integrations << integration1
        iaa_order2.integrations << integration2
        iaa_order1.save
        iaa_order2.save

        create(
          :sp_return_log,
          user_id: user1.id,
          issuer: iaa1_sp.issuer,
          ial: 1,
          requested_at: inside_iaa1,
          returned_at: inside_iaa1,
          billable: true,
        )

        # 1 unique user in month 1 at IAA 2 @ IAL 2
        create(
          :sp_return_log,
          user_id: user1.id,
          ial: 2,
          issuer: iaa2_sp.issuer,
          requested_at: inside_iaa2,
          returned_at: inside_iaa2,
          billable: true,
        )

        # 2 users, each 2 auths (1 unique) in month 2 at IAA 2 @ IAL 2
        [user1, user2].each do |user|
          2.times do
            create(
              :sp_return_log,
              user_id: user.id,
              ial: 2,
              issuer: iaa2_sp.issuer,
              requested_at: inside_iaa2 + 1.month,
              returned_at: inside_iaa2 + 1.month,
              billable: true,
            )
          end
        end
      end

      context 'separate agreements and different iaas' do
        it 'counts up costs by issuer + ial, and includes iaa and app_id' do
          results = JSON.parse(report.perform(Time.zone.today), symbolize_names: true)

          rows = [
            {
              iaa: iaa1_key,
              ial1_total_auth_count: 1,
              ial2_total_auth_count: 0,
              ial1_unique_users: 1,
              ial2_unique_users: 0,
              ial1_new_unique_users: 1,
              ial2_new_unique_users: 0,
              year_month: inside_iaa1.strftime('%Y%m'),
              iaa_start_date: iaa1_range.begin.to_s,
              iaa_end_date: iaa1_range.end.to_s,
            },
            {
              iaa: iaa2_key,
              ial1_total_auth_count: 0,
              ial2_total_auth_count: 1,
              ial1_unique_users: 0,
              ial2_unique_users: 1,
              ial1_new_unique_users: 0,
              ial2_new_unique_users: 1,
              year_month: inside_iaa2.strftime('%Y%m'),
              iaa_start_date: iaa2_range.begin.to_s,
              iaa_end_date: iaa2_range.end.to_s,
            },
            {
              iaa: iaa2_key,
              ial1_total_auth_count: 0,
              ial2_total_auth_count: 4,
              ial1_unique_users: 0,
              ial2_unique_users: 2,
              ial1_new_unique_users: 0,
              ial2_new_unique_users: 1,
              year_month: (inside_iaa2 + 1.month).strftime('%Y%m'),
              iaa_start_date: iaa2_range.begin.to_s,
              iaa_end_date: iaa2_range.end.to_s,
            },
          ]

          expect(results).to match_array(rows)
        end
      end

      context 'one agreement with consecutive iaas' do
        let(:iaa_order1) do
          build_iaa_order(order_number: 1, date_range: iaa1_range, iaa_gtc: gtc1)
        end
        let(:iaa_order2) do
          build_iaa_order(order_number: 2, date_range: iaa2_range, iaa_gtc: gtc1)
        end

        let(:integration1) do
          build_integration(issuer: iaa1_sp.issuer, partner_account: partner_account1)
        end
        let(:integration2) do
          build_integration(issuer: iaa2_sp.issuer, partner_account: partner_account1)
        end

        let(:iaa2_key) { "#{gtc1.gtc_number}-#{format('%04d', iaa_order2.order_number)}" }

        let(:iaa1_range) { Date.new(2020, 4, 15)..Date.new(2021, 4, 14) }
        let(:iaa2_range) { Date.new(2021, 4, 15)..Date.new(2022, 4, 14) }
        it 'counts up costs by issuer + ial, and includes iaa and app_id' do
          results = JSON.parse(report.perform(Time.zone.today), symbolize_names: true)

          rows = [
            {
              iaa: iaa1_key,
              ial1_total_auth_count: 1,
              ial2_total_auth_count: 0,
              ial1_unique_users: 1,
              ial2_unique_users: 0,
              ial1_new_unique_users: 1,
              ial2_new_unique_users: 0,
              year_month: inside_iaa1.strftime('%Y%m'),
              iaa_start_date: iaa1_range.begin.to_s,
              iaa_end_date: iaa1_range.end.to_s,
            },
            {
              iaa: iaa2_key,
              ial1_total_auth_count: 0,
              ial2_total_auth_count: 1,
              ial1_unique_users: 0,
              ial2_unique_users: 1,
              ial1_new_unique_users: 0,
              ial2_new_unique_users: 1,
              year_month: inside_iaa2.strftime('%Y%m'),
              iaa_start_date: iaa2_range.begin.to_s,
              iaa_end_date: iaa2_range.end.to_s,
            },
            {
              iaa: iaa2_key,
              ial1_total_auth_count: 0,
              ial2_total_auth_count: 4,
              ial1_unique_users: 0,
              ial2_unique_users: 2,
              ial1_new_unique_users: 0,
              ial2_new_unique_users: 1,
              year_month: (inside_iaa2 + 1.month).strftime('%Y%m'),
              iaa_start_date: iaa2_range.begin.to_s,
              iaa_end_date: iaa2_range.end.to_s,
            },
          ]

          expect(results).to match_array(rows)
        end
      end
    end
  end

  def build_iaa_order(order_number:, date_range:, iaa_gtc:)
    create(
      :iaa_order,
      order_number: order_number,
      start_date: date_range.begin,
      end_date: date_range.end,
      iaa_gtc: iaa_gtc,
    )
  end

  def build_integration(issuer:, partner_account:)
    create(
      :integration,
      issuer: issuer,
      partner_account: partner_account,
    )
  end

  describe '#good_job_concurrency_key' do
    let(:date) { Time.zone.today }

    it 'is the job name and the date' do
      job = described_class.new(date)
      expect(job.good_job_concurrency_key).
        to eq("#{described_class::REPORT_NAME}-#{date}")
    end
  end
end
