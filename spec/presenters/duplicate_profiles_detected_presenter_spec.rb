require 'rails_helper'

RSpec.describe DuplicateProfilesDetectedPresenter do
  let(:user) { create(:user, :proofed_with_selfie) }
  let(:presenter) { described_class.new(user: user) }
  let(:profile2) { create(:profile, :facial_match_proof) }

  before do
    DuplicateProfileConfirmation.create(
      profile_id: user.active_profile.id,
      confirmed_at: Time.zone.now,
      duplicate_profile_ids: [profile2.id],
    )
  end

  describe '#associated_profiles' do
    context 'when multiple duplicate profiles were found for user' do
      let(:profile3) { create(:profile, :facial_match_proof) }

      before do
        confirmation = DuplicateProfileConfirmation.find_by(
          profile_id: user.active_profile.id,
        )
        confirmation.update!(
          duplicate_profile_ids: [profile2.id, profile3.id],
        )
      end

      it 'should return multiple elements and user element' do
        expect(presenter.associated_profiles.count).to eq(3)
      end
    end

    context 'when a single duplicate profiles were found for user' do
      it 'should return 2 elements, 1 plus duplicate element' do
        expect(presenter.associated_profiles.count).to eq(2)
      end
    end
  end
end
