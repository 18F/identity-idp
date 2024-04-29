require 'rails_helper'

RSpec.describe PendingProfilePolicy do
  let(:user) { create(:user) }
  let(:resolved_authn_context_result) do
    AuthnContextResolver.new(
      service_provider: nil,
      vtr: vtr,
      acr_values: acr_values,
    ).resolve
  end
  let(:biometric_comparison_requested) { nil }
  let(:vtr) { nil }
  let(:acr_values) { nil }

  subject(:policy) do
    described_class.new(
      user: user,
      resolved_authn_context_result: resolved_authn_context_result,
      biometric_comparison_requested: biometric_comparison_requested,
    )
  end

  describe '#user_has_pending_profile?' do
    context 'has an active non-biometric profile and biometric comparison is requested' do
      let(:idv_level) { :unsupervised_with_selfie }
      before do
        create(:profile, :active, :verified, idv_level: :legacy_unsupervised, user: user)
        create(:profile, :verify_by_mail_pending, idv_level: idv_level, user: user)
      end

      context 'with resolved authn context result' do
        let(:vtr) { ['C2.Pb'] }

        it 'has a usable pending profile' do
          expect(policy.user_has_pending_profile?).to eq(true)
        end
      end

      context 'with biometric_comparison_requested param set to true' do
        let(:biometric_comparison_requested) { true }
        let(:acr_values) { Saml::Idp::Constants::IAL2_AUTHN_CONTEXT_CLASSREF }

        it 'has a usable pending profile' do
          expect(policy.user_has_pending_profile?).to eq(true)
        end
      end
    end

    context 'no biometric comparison is requested' do
      let(:idv_level) { :legacy_unsupervised }
      let(:vtr) { ['C2'] }
      context 'user has pending profile' do
        before do
          create(:profile, :verify_by_mail_pending, idv_level: idv_level, user: user)
        end

        it { expect(policy.user_has_pending_profile?).to eq(true) }
      end

      context 'user has an active profile' do
        before do
          create(:profile, :active, :verified, idv_level: idv_level, user: user)
        end

        it { expect(policy.user_has_pending_profile?).to eq(false) }
      end

      context 'user has active legacy profile with a pending fraud biometric profile' do
        before do
          create(:profile, :active, :verified, idv_level: idv_level, user: user)
          create(:profile, :fraud_review_pending, idv_level: :unsupervised_with_selfie, user: user)
        end

        it { expect(policy.user_has_pending_profile?).to eq(true) }
      end
    end
  end
end
