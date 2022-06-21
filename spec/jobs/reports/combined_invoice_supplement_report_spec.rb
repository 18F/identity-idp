require 'rails_helper'

RSpec.describe Reports::CombinedInvoiceSupplementReport do
  subject(:report) { Reports::CombinedInvoiceSupplementReport.new }

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

  let!(:iaa2_sp1) do
    create(
      :service_provider,
      iaa: iaa2,
      iaa_start_date: iaa2_range.begin,
      iaa_end_date: iaa2_range.end,
    )
  end
  let!(:iaa2_sp2) do
    create(
      :service_provider,
      iaa: iaa2,
      iaa_start_date: iaa2_range.begin,
      iaa_end_date: iaa2_range.end,
    )
  end

  let(:iaa1) { 'iaa1' }
  let(:iaa1_range) { Date.new(2020, 4, 15)..Date.new(2021, 4, 14) }
  let(:inside_iaa1) { iaa1_range.begin + 1.day }

  let(:iaa2) { 'iaa2' }
  let(:iaa2_range) { Date.new(2020, 9, 1)..Date.new(2021, 8, 30) }
  let(:inside_iaa2) { iaa2_range.begin + 1.day }

  describe '#perform' do
    it 'is empty with no data' do
      csv = CSV.parse(report.perform(Time.zone.today), headers: true)
      expect(csv).to be_empty
    end

    context 'with data' do
      let(:user1) { create(:user) }
      let(:user2) { create(:user) }

      before do
        iaa_order1.integrations << build_integration(
          issuer: iaa1_sp.issuer,
          partner_account: partner_account1,
        )
        iaa_order2.integrations << build_integration(
          issuer: iaa2_sp1.issuer,
          partner_account: partner_account2,
        )
        iaa_order2.integrations << build_integration(
          issuer: iaa2_sp2.issuer,
          partner_account: partner_account2,
        )
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

        # 1 unique user in month 1 at IAA 2 sp 1 @ IAL 2
        create(
          :monthly_sp_auth_count,
          user_id: user1.id,
          auth_count: 1,
          ial: 2,
          issuer: iaa2_sp1.issuer,
          year_month: inside_iaa2.strftime('%Y%m'),
        )

        # 1 unique user in month 1 at IAA 2 sp 2 @ IAL 2
        create(
          :monthly_sp_auth_count,
          user_id: user2.id,
          auth_count: 1,
          ial: 2,
          issuer: iaa2_sp2.issuer,
          year_month: inside_iaa2.strftime('%Y%m'),
        )
      end

      it 'generates a report by iaa + order number and issuer and year month' do
        csv = CSV.parse(report.perform(Time.zone.today), headers: true)

        expect(csv.length).to eq(3)

        aggregate_failures do
          row = csv.find { |r| r['issuer'] == iaa1_sp.issuer }
          expect(row['iaa_order_number']).to eq('gtc1234-0001')
          expect(row['iaa_start_date']).to eq('2020-04-15')
          expect(row['iaa_end_date']).to eq('2021-04-14')

          expect(row['issuer']).to eq(iaa1_sp.issuer)
          expect(row['friendly_name']).to eq(iaa1_sp.friendly_name)

          expect(row['year_month']).to eq('202004')
          expect(row['year_month_readable']).to eq('April 2020')

          expect(row['iaa_ial1_unique_users'].to_i).to eq(1)
          expect(row['iaa_ial2_unique_users'].to_i).to eq(0)
          expect(row['iaa_ial1_plus_2_unique_users'].to_i).to eq(1)
          expect(row['iaa_ial2_new_unique_users'].to_i).to eq(0)

          expect(row['issuer_ial1_total_auth_count'].to_i).to eq(1)
          expect(row['issuer_ial2_total_auth_count'].to_i).to eq(0)
          expect(row['issuer_ial1_plus_2_total_auth_count'].to_i).to eq(1)

          expect(row['issuer_ial1_unique_users'].to_i).to eq(1)
          expect(row['issuer_ial2_unique_users'].to_i).to eq(0)
          expect(row['issuer_ial1_plus_2_unique_users'].to_i).to eq(1)
          expect(row['issuer_ial2_new_unique_users'].to_i).to eq(0)
        end

        [iaa2_sp1, iaa2_sp2].each do |sp|
          aggregate_failures do
            row = csv.find { |r| r['issuer'] == sp.issuer }

            expect(row['iaa_order_number']).to eq('gtc5678-0002')
            expect(row['iaa_start_date']).to eq('2020-09-01')
            expect(row['iaa_end_date']).to eq('2021-08-30')

            expect(row['issuer']).to eq(sp.issuer)
            expect(row['friendly_name']).to eq(sp.friendly_name)

            expect(row['year_month']).to eq('202009')
            expect(row['year_month_readable']).to eq('September 2020')

            expect(row['iaa_ial1_unique_users'].to_i).to eq(0)
            expect(row['iaa_ial2_unique_users'].to_i).to eq(2)
            expect(row['iaa_ial1_plus_2_unique_users'].to_i).to eq(2)
            expect(row['iaa_ial2_new_unique_users'].to_i).to eq(2)

            expect(row['issuer_ial1_total_auth_count'].to_i).to eq(0)
            expect(row['issuer_ial2_total_auth_count'].to_i).to eq(1)
            expect(row['issuer_ial1_plus_2_total_auth_count'].to_i).to eq(1)

            expect(row['issuer_ial1_unique_users'].to_i).to eq(0)
            expect(row['issuer_ial2_unique_users'].to_i).to eq(1)
            expect(row['issuer_ial1_plus_2_unique_users'].to_i).to eq(1)
            expect(row['issuer_ial2_new_unique_users'].to_i).to eq(1)
          end
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
