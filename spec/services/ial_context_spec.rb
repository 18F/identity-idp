require 'rails_helper'

RSpec.describe IalContext do
  let(:ial) { nil }
  let(:sp_ial) { nil }
  let(:service_provider) do
    build(
      :service_provider,
      ial: sp_ial,
    )
  end
  let(:user) { nil }
  let(:authn_context_comparison) { nil }

  subject(:ial_context) do
    IalContext.new(
      ial: ial,
      service_provider: service_provider,
      user: user,
      authn_context_comparison: authn_context_comparison,
    )
  end

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
  end

  describe '#user_ial2_verified?' do
    context 'when the user is nil' do
      let(:user) { nil }
      it { expect(ial_context.user_ial2_verified?).to eq(false) }
    end

    context 'when the user has not proofed' do
      let(:user) { create(:user, :signed_up) }
      it { expect(ial_context.user_ial2_verified?).to eq(false) }
    end

    context 'when the user has proofed for ial2' do
      let(:user) do
        create(
          :user,
          :signed_up,
          profiles: [build(:profile, :active, :verified, pii: { first_name: 'Jane' })],
        )
      end
      it { expect(ial_context.user_ial2_verified?).to eq(true) }
    end
  end

  describe '#ialmax_requested?' do
    context 'when ialmax is requested' do
      let(:ial) { Idp::Constants::IAL_MAX }
      it { expect(ial_context.ialmax_requested?).to eq(true) }
    end

    context 'when ial 1 is requested without Comparison=minimum and ial 2 SP' do
      let(:ial) { Idp::Constants::IAL1 }
      let(:authn_context_comparison) { 'exact' }
      let(:sp_ial) { 2 }
      it { expect(ial_context.ialmax_requested?).to eq(false) }
    end

    context 'when ial 1 is requested with Comparison=minimum and ial 2 SP' do
      let(:ial) { Idp::Constants::IAL1 }
      let(:authn_context_comparison) { 'minimum' }
      let(:sp_ial) { 2 }
      it { expect(ial_context.ialmax_requested?).to eq(true) }
    end

    context 'when ial 1 is requested with Comparison=minimum and ial 1 SP' do
      let(:ial) { Idp::Constants::IAL1 }
      let(:authn_context_comparison) { 'minimum' }
      let(:sp_ial) { 1 }
      it { expect(ial_context.ialmax_requested?).to eq(false) }
    end

    context 'when ial 2 is requested' do
      let(:ial) { Idp::Constants::IAL2 }
      it { expect(ial_context.ialmax_requested?).to eq(false) }
    end
  end

  describe '#bill_for_ial_1_or_2' do
    context 'when ial is nil' do
      let(:ial) { nil }
      it { expect(ial_context.bill_for_ial_1_or_2).to eq(1) }
    end

    context 'when ial1' do
      let(:ial) { Idp::Constants::IAL1 }
      it { expect(ial_context.bill_for_ial_1_or_2).to eq(1) }
    end

    context 'when ial2' do
      let(:ial) { Idp::Constants::IAL2 }
      it { expect(ial_context.bill_for_ial_1_or_2).to eq(2) }
    end

    context 'when ial max and the user is nil' do
      let(:ial) { Idp::Constants::IAL_MAX }
      let(:user) { nil }
      it { expect(ial_context.bill_for_ial_1_or_2).to eq(1) }
    end

    context 'when ial max and the user has not proofed' do
      let(:ial) { Idp::Constants::IAL_MAX }
      let(:user) { create(:user, :signed_up) }
      it { expect(ial_context.bill_for_ial_1_or_2).to eq(1) }
    end

    context 'when ial max and the user has proofed for ial2' do
      let(:ial) { Idp::Constants::IAL_MAX }
      let(:user) do
        create(
          :user,
          :signed_up,
          profiles: [build(:profile, :active, :verified, pii: { first_name: 'Jane' })],
        )
      end
      it { expect(ial_context.bill_for_ial_1_or_2).to eq(2) }
    end
  end

  describe '#ial2_or_greater?' do
    context 'when the service provider is ial1 and ial1 is requested' do
      let(:sp_ial) { Idp::Constants::IAL1 }
      let(:ial) { Idp::Constants::IAL1 }
      it { expect(ial_context.ial2_or_greater?).to eq(false) }
    end

    context 'when the service provider is ial1 and ial is not requested' do
      let(:sp_ial) { Idp::Constants::IAL1 }
      let(:ial) { nil }
      it { expect(ial_context.ial2_or_greater?).to eq(false) }
    end

    context 'when the service provider is ial2 and ial2 is requested' do
      let(:sp_ial) { Idp::Constants::IAL2 }
      let(:ial) { Idp::Constants::IAL2 }
      it { expect(ial_context.ial2_or_greater?).to eq(true) }
    end

    context 'when the service provider is ial2 and ial is not requested' do
      let(:sp_ial) { Idp::Constants::IAL2 }
      let(:ial) { nil }
      it { expect(ial_context.ial2_or_greater?).to eq(true) }
    end

    context 'when the service provider is ial2 and ial1 is requested' do
      let(:sp_ial) { Idp::Constants::IAL2 }
      let(:ial) { Idp::Constants::IAL1 }
      it { expect(ial_context.ial2_or_greater?).to eq(false) }
    end

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
  end

  describe '#ial2_requested?' do
    context 'when ialmax is requested without a user' do
      let(:ial) { Idp::Constants::IAL_MAX }
      it { expect(ial_context.ial2_requested?).to eq(false) }
    end

    context 'when ialmax is requested with a user with no profile' do
      let(:ial) { Idp::Constants::IAL_MAX }
      let(:user) { create(:user, :signed_up) }
      it { expect(ial_context.ial2_requested?).to eq(false) }
    end

    context 'when ialmax is requested with a user with a verified profile' do
      let(:ial) { Idp::Constants::IAL_MAX }
      let(:user) { create(:profile, :active, :verified).user }
      it { expect(ial_context.ial2_requested?).to eq(true) }
    end

    context 'when ial 1 is requested' do
      let(:ial) { Idp::Constants::IAL1 }
      it { expect(ial_context.ial2_requested?).to eq(false) }
    end

    context 'when ial 2 is requested' do
      let(:ial) { Idp::Constants::IAL2 }
      it { expect(ial_context.ial2_requested?).to eq(true) }
    end

    context 'when the SP is nil' do
      let(:service_provider) { nil }
      let(:ial) { Idp::Constants::IAL2 }
      it { expect(ial_context.ial2_requested?).to eq(true) }
    end
  end
end
