require 'rails_helper'

describe VendorStatus do
  let(:from) { nil }
  let(:from_idv) { nil }
  let(:sp) { nil }
  subject(:vendor_status) do
    VendorStatus.new(from: from, from_idv: from_idv, sp: sp)
  end

  it 'raises an error if passed an unknown vendor' do
    expect { subject.vendor_outage?(:unknown_vendor) }.to raise_error(ArgumentError)
  end

  context 'when all vendors are operational' do
    before do
      VendorStatus::ALL_VENDORS.each do |vendor|
        allow(IdentityConfig.store).to receive("vendor_status_#{vendor}".to_sym).
          and_return(:operational)
      end
    end

    it 'correctly reports no vendor outage' do
      expect(subject.any_vendor_outage?).not_to be
    end

    it 'correctly reports no ial2 vendor outage' do
      expect(subject.any_ial2_vendor_outage?).not_to be
    end
  end

  context 'when any vendor has an outage' do
    VendorStatus::ALL_VENDORS.each do |vendor|
      before do
        allow(IdentityConfig.store).to receive("vendor_status_#{vendor}".to_sym).
          and_return(:full_outage)
      end

      it "correctly reports a vendor outage when #{vendor} is offline" do
        expect(subject.any_vendor_outage?).to be
      end
    end
  end

  context 'when an ial2 vendor has an outage' do
    before do
      allow(IdentityConfig.store).to receive(:vendor_status_acuant).
        and_return(:full_outage)
    end

    it 'correctly reports an ial2 vendor outage' do
      expect(subject.any_ial2_vendor_outage?).to be
    end

    context 'user coming from create_account' do
      let(:from) { SignUp::RegistrationsController::CREATE_ACCOUNT }

      it 'returns the correct message' do
        expect(subject.outage_message).to eq I18n.t('vendor_outage.idv_blocked.generic')
      end
    end

    context 'user coming from idv flow' do
      let(:from) { :welcome }
      let(:from_idv) { true }

      context 'no service_provider in session' do
        it 'returns the correct message' do
          expect(subject.outage_message).to eq(
            I18n.t('vendor_outage.idv_blocked.without_sp'),
          )
        end
      end

      context 'with service_provider in session' do
        let(:sp) { create(:service_provider) }

        it 'returns the correct message tailored to the service provider' do
          expect(subject.outage_message).to eq(
            I18n.t(
              'vendor_outage.idv_blocked.with_sp',
              service_provider: sp.friendly_name,
            ),
          )
        end
      end
    end
  end

  context 'when a non-ial2 vendor has an outage' do
    before do
      allow(IdentityConfig.store).to receive(:vendor_status_sms).
        and_return(:full_outage)
    end

    it 'correctly reports no ial2 vendor outage' do
      expect(subject.any_ial2_vendor_outage?).not_to be
    end
  end
end
