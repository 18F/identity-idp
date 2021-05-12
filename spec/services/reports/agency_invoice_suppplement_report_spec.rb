require 'rails_helper'

RSpec.describe Reports::AgencyInvoiceSupplementReport do
  subject(:report) { Reports::AgencyInvoiceSupplementReport.new }

  describe '#call' do
    it 'is empty with no data' do
      expect(report.call).to eq('[]')
    end

    context 'with data' do
      let(:iaa1) { 'iaa1' }
      let(:iaa1_range) { Date.new(2020, 9, 1)..Date.new(2021, 9, 1) }
      let(:inside_iaa1) { iaa1_range.begin + 1.day }

      let(:iaa2) { 'iaa2' }
      let(:iaa2_range) { Date.new(2020, 4, 15)..Date.new(2021, 4, 15) }
      let(:inside_iaa2) { iaa2_range.begin + 1.day }

      let!(:iaa1_sps) do
        1.times.map do
          create(
            :service_provider,
            iaa: iaa1,
            iaa_start_date: iaa1_range.begin,
            iaa_end_date: iaa1_range.end,
            app_id: SecureRandom.hex,
          )
        end
      end

      let!(:iaa2_sps) do
        2.times.map do
          create(
            :service_provider,
            iaa: iaa2,
            iaa_start_date: iaa2_range.begin,
            iaa_end_date: iaa2_range.end,
            app_id: SecureRandom.hex,
          )
        end
      end

      before do
        # 1x IAL 1 at each iaa1 SP
        iaa1_sps.map do |sp|
          create(
            :sp_cost,
            issuer: sp.issuer,
            cost_type:
            'authentication',
            ial: 1,
            created_at: inside_iaa1,
          )
        end

        # 2x IAL 2 at each iaa2 SP
        iaa2_sps.map do |sp|
          2.times do
            create(
              :sp_cost,
              issuer: sp.issuer,
              cost_type: 'authentication',
              ial: 2,
              created_at: inside_iaa2,
            )
          end
        end
      end

      it 'counts up costs by issuer + ial, and includes iaa and app_id' do
        results = JSON.parse(report.call, symbolize_names: true)

        rows = iaa1_sps.map do |sp|
          {
            issuer: sp.issuer,
            ial: 1,
            cost_type: 'authentication',
            iaa: sp.iaa,
            app_id: sp.app_id,
            count: 1,
          }
        end + iaa2_sps.map do |sp|
          {
            issuer: sp.issuer,
            ial: 2,
            cost_type: 'authentication',
            iaa: sp.iaa,
            app_id: sp.app_id,
            count: 2,
          }
        end

        expect(results).to match_array(rows)
      end
    end
  end
end