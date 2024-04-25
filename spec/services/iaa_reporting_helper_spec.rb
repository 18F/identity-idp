require 'rails_helper'

RSpec.describe IaaReportingHelper do
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

  let(:integration1) do
    build_integration(service_provider: iaa1_sp, partner_account: partner_account1)
  end
  let(:integration2) do
    build_integration(service_provider: iaa2_sp, partner_account: partner_account2)
  end

  # Have to do this because of invalid check when building integration usages
  let!(:iaa_orders) do
    [
      iaa_order1,
      iaa_order2,
    ]
  end

  let(:iaa1) { 'iaa1' }
  let(:iaa1_key) { "#{gtc1.gtc_number}-#{format('%04d', iaa_order1.order_number)}" }
  let(:iaa1_range) { Date.new(2020, 4, 15)..Date.new(2021, 4, 14) }

  let(:iaa2) { 'iaa2' }
  let(:iaa2_key) { "#{gtc2.gtc_number}-#{format('%04d', iaa_order2.order_number)}" }
  let(:iaa2_range) { Date.new(2020, 9, 1)..Date.new(2021, 8, 30) }

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

  def build_iaa_order(order_number:, date_range:, iaa_gtc:)
    create(
      :iaa_order,
      order_number: order_number,
      start_date: date_range.begin,
      end_date: date_range.end,
      iaa_gtc: iaa_gtc,
    )
  end

  def build_integration(service_provider:, partner_account:)
    create(
      :integration,
      service_provider: service_provider,
      partner_account: partner_account,
    )
  end

  describe '#iaas' do
    before do
      iaa_order1.integrations << integration1
      iaa_order2.integrations << integration2
      iaa_order1.save
      iaa_order2.save
    end

    context 'multiple IAAs on same GTC' do
      let(:iaa_order1) do
        build_iaa_order(order_number: 1, date_range: iaa1_range, iaa_gtc: gtc1)
      end
      let(:iaa_order2) do
        build_iaa_order(order_number: 2, date_range: iaa2_range, iaa_gtc: gtc1)
      end

      let(:integration2) do
        build_integration(service_provider: iaa2_sp, partner_account: partner_account1)
      end

      let(:iaa2_key) { "#{gtc1.gtc_number}-#{format('%04d', iaa_order2.order_number)}" }

      let(:iaa1_range) { Date.new(2020, 4, 15)..Date.new(2021, 4, 14) }
      let(:iaa2_range) { Date.new(2021, 4, 14)..Date.new(2022, 4, 13) }

      it 'returns both fo the IAAS with the proper key' do
        iaas = IaaReportingHelper.iaas
        orders = iaas.select { |obj| obj.gtc_number == gtc1.gtc_number }
        # Expect IAAS with matching GTC to appear
        expect(orders.count).to eq(2)
      end
    end

    context 'IAAS on different GTCs' do
      let(:integration1) do
        build_integration(service_provider: iaa1_sp, partner_account: partner_account1)
      end
      let(:integration2) do
        build_integration(service_provider: iaa2_sp, partner_account: partner_account2)
      end
      let(:iaa_order1) do
        build_iaa_order(order_number: 1, date_range: iaa1_range, iaa_gtc: gtc1)
      end
      let(:iaa_order2) do
        build_iaa_order(order_number: 2, date_range: iaa2_range, iaa_gtc: gtc2)
      end

      it 'returns both of the IAAS with the proper key of different GTCs' do
        iaas = IaaReportingHelper.iaas
        gtc1_orders = iaas.select { |obj| obj.gtc_number == gtc1.gtc_number }
        gtc2_orders = iaas.select { |obj| obj.gtc_number == gtc2.gtc_number }
        expect(gtc1_orders.count).to eq(1)
        expect(gtc2_orders.count).to eq(1)
      end
    end
  end

  describe '#partner_accounts' do
    let(:service_provider1) { create(:service_provider) }
    let(:service_provider2) { create(:service_provider) }
    let(:service_provider3) { create(:service_provider) }

    before do
      partner_account1.integrations << integration3
      partner_account2.integrations << integration4
      iaa_order1.integrations << integration3
      iaa_order2.integrations << integration4
      iaa_order2.integrations << integration5
      iaa_order1.save
      iaa_order2.save
    end

    context 'SPS on different Partners' do
      let(:integration3) do
        build_integration(service_provider: service_provider1, partner_account: partner_account1)
      end
      let(:integration4) do
        build_integration(service_provider: service_provider2, partner_account: partner_account2)
      end
      let(:integration5) do
        build_integration(service_provider: service_provider3, partner_account: partner_account2)
      end

      it 'returns partner requesting_agency for the given partneraccountid for serviceproviders' do
        expect(IaaReportingHelper.partner_accounts).to include(
          IaaReportingHelper::PartnerConfig.new(
            partner: partner_account1.requesting_agency,
            issuers: [service_provider1.issuer],
            start_date: iaa1_range.begin,
            end_date: iaa1_range.end,
          ),
          IaaReportingHelper::PartnerConfig.new(
            partner: partner_account2.requesting_agency,
            issuers: [service_provider2.issuer, service_provider3.issuer].sort,
            start_date: iaa2_range.begin,
            end_date: iaa2_range.end,
          ),
        )
      end
    end
  end
end
