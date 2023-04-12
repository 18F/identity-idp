require 'rails_helper'

RSpec.describe Reports::AgreementSummaryReport do
  subject(:report) { Reports::AgreementSummaryReport.new }

  before do
    Agreements::IntegrationUsage.delete_all
    Agreements::IaaOrder.delete_all
    Agreements::IaaGtc.delete_all
  end

  describe '#perform' do
    it 'is empty with no data' do
      csv = CSV.parse(report.perform(Time.zone.today), headers: true)
      expect(csv).to be_empty
    end

    context 'with iaa data' do
      let(:sp1) { create(:service_provider, issuer: 'aaa', friendly_name: 'App A') }
      let(:sp2) { create(:service_provider, issuer: 'bbb', friendly_name: 'App B') }

      let(:partner_account) { build(:partner_account) }

      let(:gtc) do
        create(
          :iaa_gtc,
          gtc_number: 'gtc1234',
          partner_account: partner_account,
          start_date: Date.new(2021, 1, 1),
          end_date: Date.new(2021, 12, 31),
        )
      end

      let(:order_number) { 111 }

      before do
        iaa_order = create(
          :iaa_order,
          order_number: order_number,
          start_date: Date.new(2021, 1, 1),
          end_date: Date.new(2021, 12, 31),
          iaa_gtc: gtc,
        )
        iaa_order.integrations << build(
          :integration,
          issuer: sp1.issuer,
          partner_account: partner_account,
        )
        iaa_order.integrations << build(
          :integration,
          issuer: sp2.issuer,
          partner_account: partner_account,
        )
      end

      it 'it loads IAA data into a CSV' do
        csv = CSV.parse(report.perform(Time.zone.today), headers: true)

        aggregate_failures do
          row = csv.first
          expect(row['gtc_number']).to eq('gtc1234')
          expect(row['order_number']).to eq(order_number.to_s)
          expect(row['issuer']).to eq(sp1.issuer)
          expect(row['friendly_name']).to eq(sp1.friendly_name)
          expect(row['start_date']).to eq('2021-01-01')
          expect(row['end_date']).to eq('2021-12-31')
        end

        aggregate_failures do
          row = csv[1]
          expect(row['gtc_number']).to eq('gtc1234')
          expect(row['order_number']).to eq(order_number.to_s)
          expect(row['issuer']).to eq(sp2.issuer)
          expect(row['friendly_name']).to eq(sp2.friendly_name)
          expect(row['start_date']).to eq('2021-01-01')
          expect(row['end_date']).to eq('2021-12-31')
        end
      end
    end
  end
end
