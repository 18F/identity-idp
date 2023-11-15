require 'rails_helper'

RSpec.describe OutageStatus do
  subject(:vendor_status) do
    OutageStatus.new
  end

  it 'raises an error if passed an unknown vendor' do
    expect { subject.vendor_outage?(:unknown_vendor) }.to raise_error(ArgumentError)
  end

  context 'when all vendors are operational' do
    before do
      OutageStatus::ALL_VENDORS.each do |vendor|
        allow(IdentityConfig.store).to receive("vendor_status_#{vendor}".to_sym).
          and_return(:operational)
      end
    end

    it 'correctly reports no vendor outage' do
      expect(subject.any_vendor_outage?).not_to be
    end

    it 'correctly reports no idv vendor outage' do
      expect(subject.any_idv_vendor_outage?).not_to be
    end
  end

  context 'when any vendor has an outage' do
    OutageStatus::ALL_VENDORS.each do |vendor|
      before do
        allow(IdentityConfig.store).to receive("vendor_status_#{vendor}".to_sym).
          and_return(:full_outage)
      end

      it "correctly reports a vendor outage when #{vendor} is offline" do
        expect(subject.any_vendor_outage?).to be
      end
    end
  end

  context 'when an idv vendor has an outage' do
    before do
      allow(IdentityConfig.store).to receive(:vendor_status_acuant).
        and_return(:full_outage)
    end

    it 'correctly reports an idv vendor outage' do
      expect(subject.any_idv_vendor_outage?).to be
    end

    it 'returns the correct message' do
      expect(subject.outage_message).to eq I18n.t('vendor_outage.blocked.idv.generic')
    end
  end

  context 'when a non-idv vendor has an outage' do
    before do
      allow(IdentityConfig.store).to receive(:vendor_status_sms).
        and_return(:full_outage)
    end

    it 'correctly reports no idv vendor outage' do
      expect(subject.any_idv_vendor_outage?).not_to be
    end
  end

  describe '#all_vendor_outage?' do
    it { expect(subject.all_vendor_outage?).to eq(false) }

    context 'with outage on all vendors' do
      before do
        allow(vendor_status).to receive(:vendor_outage?).and_return(true)
      end

      it { expect(subject.all_vendor_outage?).to eq(true) }
    end

    context 'with parameters' do
      let(:vendor) { :sms }

      it { expect(subject.all_vendor_outage?([vendor])).to eq(false) }

      context 'with outage on all vendors' do
        before do
          allow(vendor_status).to receive(:vendor_outage?).with(vendor).and_return(true)
        end

        it { expect(subject.all_vendor_outage?([vendor])).to eq(true) }
      end
    end
  end

  describe '#any_phone_vendor_outage?' do
    it { expect(subject.any_phone_vendor_outage?).to eq(false) }

    context 'with outage on a phone vendor' do
      before do
        allow(vendor_status).to receive(:vendor_outage?).with(:sms).and_return(true)
      end

      it { expect(subject.any_phone_vendor_outage?).to eq(true) }
    end
  end

  describe '#all_phone_vendor_outage?' do
    it { expect(subject.all_phone_vendor_outage?).to eq(false) }

    context 'with outage on a phone vendor' do
      before do
        allow(vendor_status).to receive(:vendor_outage?).and_return(false)
        allow(vendor_status).to receive(:vendor_outage?).with(:sms).and_return(true)
      end

      it { expect(subject.all_phone_vendor_outage?).to eq(false) }
    end

    context 'with outage on all phone vendors' do
      before do
        allow(vendor_status).to receive(:vendor_outage?).and_return(true)
      end

      it { expect(subject.all_phone_vendor_outage?).to eq(true) }
    end
  end

  describe '#idv_scheduled_maintenance_status' do
    let(:start) { '2023-01-01T00:00:00Z' }
    let(:finish) { '2023-01-01T23:59:59Z' }

    subject(:status) { vendor_status.idv_scheduled_maintenance_status }

    before do
      allow(IdentityConfig.store).to receive(:vendor_status_idv_scheduled_maintenance_start).
        and_return(start)
      allow(IdentityConfig.store).to receive(:vendor_status_idv_scheduled_maintenance_finish).
        and_return(finish)

      travel_to(now)
    end

    context 'outside of a scheduled maintenance window' do
      let(:now) { Time.zone.parse('2023-03-01T00:00:00Z') }

      it { is_expected.to eq(:operational) }
    end

    context 'inside of a scheduled maintenance window' do
      let(:now) { Time.zone.parse('2023-01-01T12:00:00Z') }

      it { is_expected.to eq(:full_outage) }

      it 'is reported as an IDV outage' do
        expect(vendor_status.any_idv_vendor_outage?).to eq(true)
      end
    end
  end

  describe '#outage_message' do
    subject(:outage_message) { vendor_status.outage_message }

    context 'phone vendor outage' do
      before do
        allow(vendor_status).to receive(:vendor_outage?).and_return(false)
        OutageStatus::PHONE_VENDORS.each do |vendor|
          allow(vendor_status).to receive(:vendor_outage?).with(vendor).and_return(true)
        end
      end

      it 'returns default phone outage message' do
        expect(outage_message).to eq(t('vendor_outage.blocked.phone.default'))
      end
    end
  end

  describe '#track_event' do
    it 'logs status of all vendors' do
      analytics = FakeAnalytics.new
      expect(analytics).to receive(:track_event).with(
        'Vendor Outage',
        redirect_from: nil,
        vendor_status: OutageStatus::ALL_VENDORS.index_with do |_vendor|
          satisfy { |status| IdentityConfig::VENDOR_STATUS_OPTIONS.include?(status) }
        end,
      )

      vendor_status.track_event(analytics)
    end
  end
end
