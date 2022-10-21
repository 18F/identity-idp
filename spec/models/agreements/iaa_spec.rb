require 'rails_helper'

RSpec.describe Agreements::Iaa do
  let(:gtc) { create(:iaa_gtc, gtc_number: 'LGABC210001') }
  let(:order) { create(:iaa_order, iaa_gtc: gtc, order_number: 1, mod_number: 2) }
  let(:iaa) { described_class.new(gtc: gtc, order: order) }

  it { is_expected.to delegate_method(:gtc_number).to(:gtc) }
  it { is_expected.to delegate_method(:mod_number).to(:gtc).with_prefix }
  it { is_expected.to delegate_method(:start_date).to(:gtc).with_prefix }
  it { is_expected.to delegate_method(:end_date).to(:gtc).with_prefix }
  it { is_expected.to delegate_method(:estimated_amount).to(:gtc).with_prefix }
  it { is_expected.to delegate_method(:status).to(:gtc).with_prefix }
  it { is_expected.to delegate_method(:order_number).to(:order) }
  it { is_expected.to delegate_method(:mod_number).to(:order).with_prefix }
  it { is_expected.to delegate_method(:start_date).to(:order).with_prefix }
  it { is_expected.to delegate_method(:end_date).to(:order).with_prefix }
  it { is_expected.to delegate_method(:estimated_amount).to(:order).with_prefix }
  it { is_expected.to delegate_method(:status).to(:order).with_prefix }

  describe 'attributes' do
    describe 'ial2_users' do
      it 'defaults to zero' do
        expect(iaa.ial2_users).to eq(0)
      end
      it 'can be set to a custom value' do
        iaa.ial2_users = 10
        expect(iaa.ial2_users).to eq(10)
      end
    end

    describe 'authentications' do
      it 'defaults to an empty hash' do
        expect(iaa.authentications).to eq({})
      end
      it 'can be set to a custom value' do
        iaa.authentications = { 'issuer1' => 10 }
        expect(iaa.authentications).to eq({ 'issuer1' => 10 })
      end
    end
  end

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

  describe 'delegated methods' do
    it 'does not permit arbitrary sends to the gtc or order objects' do
      expect { iaa.send(:gtc_not_permitted) }.to raise_error(NoMethodError)
      expect { iaa.send(:order_not_permitted) }.to raise_error(NoMethodError)
    end
  end

  describe '#==' do
    it 'returns true when both the order and the gtc are equal' do
      other = described_class.new(gtc: gtc, order: order)
      expect(iaa).to eq(other)
    end

    it 'returns false when the order does not match' do
      other_order = create(:iaa_order, iaa_gtc: gtc)
      other = described_class.new(gtc: gtc, order: other_order)
      expect(iaa).not_to eq(other)
    end
  end
end
