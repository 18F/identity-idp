require 'rails_helper'

RSpec.describe IalContext do
  let(:ial) { nil }
  let(:sp_liveness_checking_required) { false }
  let(:sp_ial) { nil }
  let(:service_provider) do
    build(:service_provider,
          liveness_checking_required: sp_liveness_checking_required,
          ial: sp_ial)
  end

  subject(:ial_context) { IalContext.new(ial: ial, service_provider: service_provider) }

  describe '#ial' do
    context 'with an integer input' do
      let(:ial) { Idp::Constants::IAL2 }
      it { expect(ial_context.ial).to eq(2) }
    end

    context 'with a string input of an authn context' do
      let(:ial) { Saml::Idp::Constants::IAL1_AUTHN_CONTEXT_CLASSREF }
      it { expect(ial_context.ial).to eq(1) }
    end

    context 'with a bad string input' do
      let(:ial) { '/aaaa' }
      it { expect { ial_context.ial }.to raise_error(KeyError) }
    end

    context 'with a nil input' do
      it { expect(ial_context.ial).to eq(nil) }
    end
  end

  describe '#ial2_service_provider?' do
    context 'when the service provider is ial1' do
      let(:sp_ial) { Idp::Constants::IAL1 }
      it { expect(ial_context.ial2_service_provider?).to eq(false) }
    end

    context 'when the service provider is ial2' do
      let(:sp_ial) { Idp::Constants::IAL2 }
      it { expect(ial_context.ial2_service_provider?).to eq(true) }
    end

    context 'when the service provider is ial2 strict' do
      let(:sp_ial) { Idp::Constants::IAL2_STRICT }
      it { expect(ial_context.ial2_service_provider?).to eq(true) }
    end

    context 'when the service provider is ial3' do
      let(:sp_ial) { 3 }
      it { expect(ial_context.ial2_service_provider?).to eq(true) }
    end
  end

  describe '#default_to_ial2?' do
    context 'when the service provider is ial1 and ial1 is requested' do
      let(:sp_ial) { Idp::Constants::IAL1 }
      let(:ial) { Idp::Constants::IAL1 }
      it { expect(ial_context.default_to_ial2?).to eq(false) }
    end

    context 'when the service provider is ial1 and ial is not requested' do
      let(:sp_ial) { Idp::Constants::IAL1 }
      let(:ial) { nil }
      it { expect(ial_context.default_to_ial2?).to eq(false) }
    end

    context 'when the service provider is ial2 and ial2 is requested' do
      let(:sp_ial) { Idp::Constants::IAL2 }
      let(:ial) { Idp::Constants::IAL2 }
      it { expect(ial_context.default_to_ial2?).to eq(false) }
    end

    context 'when the service provider is ial2 and ial is not requested' do
      let(:sp_ial) { Idp::Constants::IAL2 }
      let(:ial) { nil }
      it { expect(ial_context.default_to_ial2?).to eq(true) }
    end

    context 'when the service provider is ial2 and ial1 is requested' do
      let(:sp_ial) { Idp::Constants::IAL2 }
      let(:ial) { Idp::Constants::IAL1 }
      it { expect(ial_context.default_to_ial2?).to eq(false) }
    end

    context 'when the service provider is ial2 strict and ial1 is requested' do
      let(:sp_ial) { Idp::Constants::IAL2_STRICT }
      let(:ial) { Idp::Constants::IAL1 }
      it { expect(ial_context.default_to_ial2?).to eq(false) }
    end

    context 'when the service provider is ial2 strict and ial2 is requested' do
      let(:sp_ial) { Idp::Constants::IAL2_STRICT }
      let(:ial) { Idp::Constants::IAL2 }
      it { expect(ial_context.default_to_ial2?).to eq(false) }
    end

    context 'when the service provider is ial2 strict and ial2 is requested' do
      let(:sp_ial) { Idp::Constants::IAL2_STRICT }
      let(:ial) { nil }
      it { expect(ial_context.default_to_ial2?).to eq(true) }
    end
  end

  describe '#ialmax_requested?' do
    context 'when ialmax is requested' do
      let(:ial) { Idp::Constants::IAL_MAX }
      it { expect(ial_context.ialmax_requested?).to eq(true) }
    end

    context 'when ial 1 is requested' do
      let(:ial) { Idp::Constants::IAL1 }
      it { expect(ial_context.ialmax_requested?).to eq(false) }
    end

    context 'when ial 2 is requested' do
      let(:ial) { Idp::Constants::IAL2 }
      it { expect(ial_context.ialmax_requested?).to eq(false) }
    end

    context 'when ial 2 strict is requested' do
      let(:ial) { Idp::Constants::IAL2_STRICT }
      it { expect(ial_context.ialmax_requested?).to eq(false) }
    end
  end

  describe '#ial2_or_greater?' do
    context 'when ialmax is requested' do
      let(:ial) { Idp::Constants::IAL_MAX }
      it { expect(ial_context.ial2_or_greater?).to eq(false) }
    end

    context 'when ial 1 is requested' do
      let(:ial) { Idp::Constants::IAL1 }
      it { expect(ial_context.ial2_or_greater?).to eq(false) }
    end

    context 'when ial 2 is requested' do
      let(:ial) { Idp::Constants::IAL2 }
      it { expect(ial_context.ial2_or_greater?).to eq(true) }
    end

    context 'when ial 2 is requested and the sp requires liveness checking' do
      let(:ial) { Idp::Constants::IAL2 }
      let(:sp_liveness_checking_required) { true }
      it { expect(ial_context.ial2_or_greater?).to eq(true) }
    end

    context 'when ial 2 strict is requested' do
      let(:ial) { Idp::Constants::IAL2_STRICT }
      it { expect(ial_context.ial2_or_greater?).to eq(true) }
    end
  end

  describe '#ial2_requested?' do
    context 'when ialmax is requested' do
      let(:ial) { Idp::Constants::IAL_MAX }
      it { expect(ial_context.ial2_requested?).to eq(false) }
    end

    context 'when ial 1 is requested' do
      let(:ial) { Idp::Constants::IAL1 }
      it { expect(ial_context.ial2_requested?).to eq(false) }
    end

    context 'when ial 2 is requested' do
      let(:ial) { Idp::Constants::IAL2 }
      it { expect(ial_context.ial2_requested?).to eq(true) }
    end

    context 'when ial 2 is requested and the sp requires liveness checking' do
      let(:ial) { Idp::Constants::IAL2 }
      let(:sp_liveness_checking_required) { true }
      it { expect(ial_context.ial2_requested?).to eq(true) }
    end

    context 'when ial 2 strict is requested' do
      let(:ial) { Idp::Constants::IAL2_STRICT }
      it { expect(ial_context.ial2_requested?).to eq(false) }
    end

    context 'when the SP is nil' do
      let(:service_provider) { nil }
      let(:ial) { Idp::Constants::IAL2 }
      it { expect(ial_context.ial2_requested?).to eq(true) }
    end
  end

  describe '#ial2_strict_requested?' do
    context 'with the strict authn context passed in' do
      let(:ial) { Saml::Idp::Constants::IAL2_STRICT_AUTHN_CONTEXT_CLASSREF }
      it { expect(ial_context.ial2_strict_requested?).to eq(true) }
    end

    context 'with ial2 passed in and liveness checking required on the sp' do
      let(:ial) { Idp::Constants::IAL2 }
      let(:sp_liveness_checking_required) { true }
      it { expect(ial_context.ial2_strict_requested?).to eq(true) }
    end

    context 'with ial1 passed in but liveness checking required on the sp' do
      let(:ial) { Idp::Constants::IAL1 }
      let(:sp_liveness_checking_required) { true }
      it { expect(ial_context.ial2_strict_requested?).to eq(false) }
    end

    context 'when the SP is nil' do
      let(:service_provider) { nil }
      let(:ial) { Idp::Constants::IAL2 }
      it { expect(ial_context.ial2_strict_requested?).to eq(false) }
    end
  end

  describe '#ial_for_identity_record' do
    context 'with ial1' do
      let(:ial) { Saml::Idp::Constants::IAL1_AUTHN_CONTEXT_CLASSREF }
      it { expect(ial_context.ial_for_identity_record).to eq(Idp::Constants::IAL1) }
    end

    context 'with ial2' do
      let(:ial) { Saml::Idp::Constants::IAL2_AUTHN_CONTEXT_CLASSREF }
      it { expect(ial_context.ial_for_identity_record).to eq(Idp::Constants::IAL2) }
    end

    context 'with ial2 and liveness checking required on the sp' do
      let(:ial) { Saml::Idp::Constants::IAL2_AUTHN_CONTEXT_CLASSREF }
      let(:sp_liveness_checking_required) { true }
      it { expect(ial_context.ial_for_identity_record).to eq(Idp::Constants::IAL2_STRICT) }
    end

    context 'with ial 2 strict' do
      let(:ial) { Saml::Idp::Constants::IAL2_STRICT_AUTHN_CONTEXT_CLASSREF }
      it { expect(ial_context.ial_for_identity_record).to eq(Idp::Constants::IAL2_STRICT) }
    end

    context 'when the SP is nil' do
      let(:service_provider) { nil }
      let(:ial) { Idp::Constants::IAL2 }
      it { expect(ial_context.ial_for_identity_record).to eq(Idp::Constants::IAL2) }
    end
  end
end
