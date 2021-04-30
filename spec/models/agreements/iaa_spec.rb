require 'rails_helper'

RSpec.describe Agreements::Iaa do
  let(:gtc) { create(:iaa_gtc, gtc_number: 'LGABC210001') }
  let(:order) { create(:iaa_order, iaa_gtc: gtc, order_number: 1, mod_number: 2) }
  let(:iaa) { described_class.new(gtc: gtc, order: order) }

  it { is_expected.to delegate_method(:gtc_number).to(:gtc) }
  it { is_expected.to delegate_method(:order_number).to(:order) }

  describe '#iaa_number' do
    it 'returns the formatted IAA number' do
      expect(iaa.iaa_number).to eq('LGABC210001-0001-0002')
    end
  end

  describe '#partner_account' do
    it 'returns the requesting agency of the partner account' do
      expect(iaa.partner_account).to eq(gtc.partner_account.requesting_agency)
    end
  end

  describe '#gtc_status' do
    it 'returns the partner-facing status of the GTC' do
      expect(iaa.gtc_status).to eq(gtc.partner_status)
    end
  end

  describe '#order_status' do
    it 'returns the partner-facing status of the order' do
      expect(iaa.order_status).to eq(order.partner_status)
    end
  end

  # other delegated methods
  %i[mod_number start_date end_date estimated_amount].each do |attribute|
    gtc_method = "gtc_#{attribute}"
    order_method = "order_#{attribute}"

    describe "##{gtc_method}" do
      it "returns the #{attribute} of the GTC" do
        expect(iaa.send(gtc_method)).to eq(gtc.send(attribute))
      end
    end

    describe "##{order_method}" do
      it "returns the #{attribute} of the order" do
        expect(iaa.send(order_method)).to eq(order.send(attribute))
      end
    end
  end
end
