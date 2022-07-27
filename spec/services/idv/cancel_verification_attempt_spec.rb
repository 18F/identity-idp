require 'rails_helper'

describe Idv::CancelVerificationAttempt do
  let(:user) { create(:user, profiles: profiles) }
  let(:profiles) { [create(:profile, deactivation_reason: :gpo_verification_pending)] }

  subject { described_class.new(user: user) }

  context 'the user has a pending profile' do
    it 'deactivates the profile' do
      subject.call

      expect(profiles[0].active).to eq(false)
      expect(profiles[0].reload.deactivation_reason).to eq('verification_cancelled')
      expect(user.reload.profiles.gpo_verification_pending).to be_empty
    end
  end

  context 'the user has multiple pending profiles' do
    let(:profiles) do
      super().push(create(:profile, deactivation_reason: :gpo_verification_pending))
    end

    it 'deactivates both profiles' do
      subject.call

      expect(profiles[0].active).to eq(false)
      expect(profiles[0].reload.deactivation_reason).to eq('verification_cancelled')
      expect(profiles[1].active).to eq(false)
      expect(profiles[1].reload.deactivation_reason).to eq('verification_cancelled')
      expect(user.reload.profiles.gpo_verification_pending).to be_empty
    end
  end

  context 'the user has a pending profile and an active profile' do
    let(:profiles) do
      super().push(create(:profile, :active))
    end

    it 'deactivates the pending profile' do
      subject.call

      expect(profiles[0].active).to eq(false)
      expect(profiles[0].reload.deactivation_reason).to eq('verification_cancelled')
      expect(profiles[1].active).to eq(true)
      expect(profiles[1].reload.deactivation_reason).to be_nil
      expect(user.reload.profiles.gpo_verification_pending).to be_empty
    end
  end

  context 'when there are pending profiles for other users' do
    it 'only updates profiles for the specificed user' do
      other_profile = create(:profile, deactivation_reason: :gpo_verification_pending)

      subject.call

      expect(profiles[0].active).to eq(false)
      expect(profiles[0].reload.deactivation_reason).to eq('verification_cancelled')
      expect(other_profile.active).to eq(false)
      expect(other_profile.reload.deactivation_reason).to eq('gpo_verification_pending')
    end
  end
end
