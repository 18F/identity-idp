require 'rails_helper'

RSpec.describe PendingProfilePolicy do
  let(:user) { create(:user) }
  let(:resolved_authn_context_result) do
    AuthnContextResolver.new(
      service_provider: nil,
      vtr: vtr,
      acr_values: nil,
    ).resolve
  end
  let(:vtr) { nil }

  subject(:policy) do
    described_class.new(
      user,
      resolved_authn_context_result,
    )
  end

  describe '#user_has_useable_pending_profile?' do
    context 'has an active non-biometric profile and biometric comparison is requested' do
      let(:idv_level) { :unsupervised_with_selfie }
      let(:vtr) { ['C2.Pb'] }
      before do
        create(:profile, :active, :verified, idv_level: :legacy_unsupervised, user: user)
        create(:profile, :verify_by_mail_pending, idv_level: idv_level, user: user)
      end

      it 'has a usable pending profile' do
        expect(policy.user_has_useable_pending_profile?).to eq(true)
      end
    end

    context 'no biometric comparison is requested' do
      let(:idv_level) { :legacy_unsupervised }
      let(:vtr) { ['C2'] }
      context 'user has pending profile' do
        before do
          create(:profile, :verify_by_mail_pending, idv_level: idv_level, user: user)
        end

        it { expect(policy.user_has_useable_pending_profile?).to eq(true) }
      end

      context 'user has an active profile' do
        before do
          create(:profile, :active, :verified, idv_level: idv_level, user: user)
        end

        it { expect(policy.user_has_useable_pending_profile?).to eq(false) }
      end

      context 'user has active legacy profile with a pending fraud biometric profile' do
        before do
          create(:profile, :active, :verified, idv_level: idv_level, user: user)
          create(:profile, :fraud_review_pending, idv_level: :unsupervised_with_selfie, user: user)
        end

        it { expect(policy.user_has_useable_pending_profile?).to eq(true) }
      end
    end
  end
end
