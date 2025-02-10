require 'rails_helper'

RSpec.describe Reports::IdvLegacyConversionSupplementReport do
  subject(:report) { Reports::IdvLegacyConversionSupplementReport.new }

  before do
    clear_agreements_data
    ServiceProvider.delete_all
  end

  describe '#perform' do
    it 'is empty with no data' do
      csv = CSV.parse(report.perform(Time.zone.today), headers: true)
      expect(csv).to be_empty
    end

    context 'with data generates reports by iaa + order number, issuer and year_month' do
      context 'when there are converted profiles in April 2020' do
        let(:partner_account1) { create(:partner_account) }
        let(:iaa1_range) { DateTime.new(2020, 4, 15).utc..DateTime.new(2021, 4, 14).utc }
        let(:gtc1) do
          create(
            :iaa_gtc,
            gtc_number: 'gtc1234',
            partner_account: partner_account1,
            start_date: iaa1_range.begin,
            end_date: iaa1_range.end,
          )
        end

        let(:iaa1) { 'iaa1' }

        let(:iaa1_sp) do
          create(
            :service_provider,
            iaa: iaa1,
            iaa_start_date: iaa1_range.begin,
            iaa_end_date: iaa1_range.end,
          )
        end

        let(:iaa_order1) do
          build_iaa_order(order_number: 1, date_range: iaa1_range, iaa_gtc: gtc1)
        end

        let(:inside_iaa1) { iaa1_range.begin + 1.day }

        let(:user1) { create(:user) }

        let(:csv) { CSV.parse(report.perform(Time.zone.today), headers: true) }

        before do
          iaa_order1.integrations << build_integration(
            issuer: iaa1_sp.issuer,
            partner_account: partner_account1,
          )
          iaa_order1.save
          create(
            :sp_upgraded_facial_match_profile,
            issuer: iaa1_sp.issuer, user_id: user1.id, upgraded_at: inside_iaa1,
          )
        end

        it 'finds the iaa related to the upgraded profile' do
          expect(csv.length).to eq(1)
          aggregate_failures do
            row = csv.find { |r| r['issuer'] == iaa1_sp.issuer }

            expect(row.to_h.symbolize_keys).to eq(
              {
                iaa_order_number: 'gtc1234-0001',
                iaa_start_date: '2020-04-15',
                iaa_end_date: '2021-04-14',
                issuer: iaa1_sp.issuer,
                friendly_name: iaa1_sp.friendly_name,
                year_month: '202004',
                year_month_readable: 'April 2020',
                user_count: '1',
              },
            )
          end
        end
      end

      context 'when there are converted profiles with two issuers in September 2020' do
        let(:partner_account2) { create(:partner_account) }
        let(:iaa2_range) { DateTime.new(2020, 9, 1).utc..DateTime.new(2021, 8, 30).utc }

        let(:gtc2) do
          create(
            :iaa_gtc,
            gtc_number: 'gtc5678',
            partner_account: partner_account2,
            start_date: iaa2_range.begin,
            end_date: iaa2_range.end,
          )
        end

        let(:iaa2) { 'iaa2' }

        let(:iaa2_sp1) do
          create(
            :service_provider,
            iaa: iaa2,
            iaa_start_date: iaa2_range.begin,
            iaa_end_date: iaa2_range.end,
          )
        end

        let(:iaa2_sp2) do
          create(
            :service_provider,
            iaa: iaa2,
            iaa_start_date: iaa2_range.begin,
            iaa_end_date: iaa2_range.end,
          )
        end

        let(:iaa_order2) do
          build_iaa_order(order_number: 2, date_range: iaa2_range, iaa_gtc: gtc2)
        end

        let(:inside_iaa2) { iaa2_range.begin + 1.day }
        let(:user1) { create(:user) }
        let(:user2) { create(:user) }
        let(:csv) { CSV.parse(report.perform(Time.zone.today), headers: true) }

        before do
          iaa_order2.integrations << build_integration(
            issuer: iaa2_sp1.issuer,
            partner_account: partner_account2,
          )
          iaa_order2.integrations << build_integration(
            issuer: iaa2_sp2.issuer,
            partner_account: partner_account2,
          )

          create(
            :sp_upgraded_facial_match_profile,
            issuer: iaa2_sp1.issuer, user_id: user1.id, upgraded_at: inside_iaa2,
          )

          create(
            :sp_upgraded_facial_match_profile,
            issuer: iaa2_sp2.issuer, user_id: user2.id, upgraded_at: inside_iaa2,
          )
        end

        it 'checks values for all profile upgrades and multiple issuers for single partner' do
          aggregate_failures do
            row = csv.find { |r| r['issuer'] == iaa2_sp1.issuer }

            expect(row.to_h.symbolize_keys).to eq(
              {
                iaa_order_number: 'gtc5678-0002',
                iaa_start_date: '2020-09-01',
                iaa_end_date: '2021-08-30',
                issuer: iaa2_sp1.issuer,
                friendly_name: iaa2_sp1.friendly_name,
                year_month: '202009',
                year_month_readable: 'September 2020',
                user_count: '1',
              },
            )
          end

          aggregate_failures do
            row = csv.find { |r| r['issuer'] == iaa2_sp2.issuer }

            expect(row.to_h.symbolize_keys).to eq(
              {
                iaa_order_number: 'gtc5678-0002',
                iaa_start_date: '2020-09-01',
                iaa_end_date: '2021-08-30',
                issuer: iaa2_sp2.issuer,
                friendly_name: iaa2_sp2.friendly_name,
                year_month: '202009',
                year_month_readable: 'September 2020',
                user_count: '1',
              },
            )
          end
          expect(csv.length).to eq(2)
        end
      end

      context 'with multiple upgraded profiles for an issuer from September-October 2020' do
        let(:partner_account3) { create(:partner_account) }

        let(:iaa3_range) { DateTime.new(2020, 9, 1).utc..DateTime.new(2021, 8, 30).utc }
        let(:expired_iaa_range) { DateTime.new(2019, 9, 1).utc..DateTime.new(2020, 8, 31).utc }

        let(:gtc3) do
          create(
            :iaa_gtc,
            gtc_number: 'gtc9101',
            partner_account: partner_account3,
            start_date: iaa3_range.begin,
            end_date: iaa3_range.end,
          )
        end

        let(:iaa3) { 'iaa3' }

        let(:iaa3_sp1) do
          create(
            :service_provider,
            iaa: iaa3,
            iaa_start_date: iaa3_range.begin,
            iaa_end_date: iaa3_range.end,
          )
        end

        let(:iaa_order3) do
          build_iaa_order(order_number: 3, date_range: iaa3_range, iaa_gtc: gtc3)
        end

        let(:iaa_order_expired) do
          build_iaa_order(order_number: 2, date_range: expired_iaa_range, iaa_gtc: gtc3)
        end

        let(:integration_1) do
          build_integration(
            issuer: iaa3_sp1.issuer,
            partner_account: partner_account3,
          )
        end

        let(:user1) { create(:user) }
        let(:user2) { create(:user) }
        let(:csv) { CSV.parse(report.perform(Time.zone.today), headers: true) }

        before do
          iaa_order3.integrations << integration_1

          create(
            :sp_upgraded_facial_match_profile,
            issuer: iaa3_sp1.issuer, user_id: user1.id, upgraded_at: iaa3_range.begin + 1.day,
          )
          create(
            :sp_upgraded_facial_match_profile,
            issuer: iaa3_sp1.issuer, user_id: user2.id, upgraded_at: iaa3_range.begin + 1.month,
          )
        end

        it 'finds data for the same issuer with different year_months' do
          expect(csv.length).to eq(2)
          aggregate_failures do
            row = csv.find { |r| r['issuer'] == iaa3_sp1.issuer && r['year_month'] == '202009' }

            expect(row['iaa_order_number']).to eq('gtc9101-0003')
            expect(row['iaa_start_date']).to eq('2020-09-01')
            expect(row['iaa_end_date']).to eq('2021-08-30')
            expect(row['issuer']).to eq(iaa3_sp1.issuer)
            expect(row['friendly_name']).to eq(iaa3_sp1.friendly_name)
            expect(row['year_month']).to eq('202009')
            expect(row['year_month_readable']).to eq('September 2020')
            expect(row['user_count']).to eq('1')
          end

          aggregate_failures do
            row = csv.find { |r| r['issuer'] == iaa3_sp1.issuer && r['year_month'] == '202010' }

            expect(row.to_h.symbolize_keys).to eq(
              {
                iaa_order_number: 'gtc9101-0003',
                iaa_start_date: '2020-09-01',
                iaa_end_date: '2021-08-30',
                issuer: iaa3_sp1.issuer,
                friendly_name: iaa3_sp1.friendly_name,
                year_month: '202010',
                year_month_readable: 'October 2020',
                user_count: '1',
              },
            )
          end
        end

        context 'when there is an expired iaa with the same issuer' do
          before do
            iaa_order_expired.integrations << integration_1
          end

          it 'does not include the expired iaa in the report' do
            expect(csv.length).to eq(2)

            row = csv.find { |r| r['issuer'] == iaa3_sp1.issuer }

            expect(row.to_h.symbolize_keys).not_to eq(
              {
                iaa_order_number: 'gtc9101-0002',
                iaa_start_date: '2019-09-01',
                iaa_end_date: '2020-08-31',
                issuer: iaa3_sp1.issuer,
                friendly_name: iaa3_sp1.friendly_name,
                year_month: '202010',
                year_month_readable: 'October 2020',
                user_count: '1',
              },
            )
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
end
