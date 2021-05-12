require 'rails_helper'

RSpec.describe Db::SpCost::SpCostSummaryByIaa do
  describe '.call' do
    let(:iaa) { 'iaa1' }
    let(:iaa_range) { Date.new(2020, 9, 1)..Date.new(2021, 9, 1) }
    let(:inside_iaa) { iaa_range.begin + 1.day }

    subject(:results) do
      Db::SpCost::SpCostSummaryByIaa.call(iaa: iaa, iaa_range: iaa_range)
    end

    it 'is empty with no data' do
      expect(results).to eq([])
    end

    context 'with data' do
      let(:sp) do
        create(
          :service_provider,
          iaa: iaa,
          iaa_start_date: iaa_range.begin,
          iaa_end_date: iaa_range.end,
          app_id: SecureRandom.hex,
        )
      end

      before do
        # 1x IAL 1
        create(
          :sp_cost,
          issuer: sp.issuer,
          cost_type:
          'authentication',
          ial: 1,
          created_at: inside_iaa,
        )
        # 1x IAL 2
        create(
          :sp_cost,
          issuer: sp.issuer,
          cost_type:
          'authentication',
          ial: 2,
          created_at: inside_iaa,
        )
      end

      it 'counts up costs by issuer + ial, and includes iaa and app_id' do
        rows = [
          {
            issuer: sp.issuer,
            ial: 1,
            cost_type: 'authentication',
            iaa: sp.iaa,
            app_id: sp.app_id,
            count: 1,
          },
          {
            issuer: sp.issuer,
            ial: 2,
            cost_type: 'authentication',
            iaa: sp.iaa,
            app_id: sp.app_id,
            count: 1,
          }
        ]

        expect(results.map(&:symbolize_keys)).to match_array(rows)
      end
    end
  end
end