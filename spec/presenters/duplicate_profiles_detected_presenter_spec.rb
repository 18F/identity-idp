require 'rails_helper'

RSpec.describe DuplicateProfilesDetectedPresenter do
  let(:user) { create(:user, :proofed_with_selfie) }
  let(:sp) { create(:service_provider) }
  let(:duplicate_profile_set) do
    create(
      :duplicate_profile_set,
      profile_ids: [user.active_profile.id, profile2.id],
      service_provider: sp,
    )
  end
  let(:presenter) { described_class.new(user: user, duplicate_profile_set: duplicate_profile_set) }
  let(:profile2) { create(:profile, :facial_match_proof) }

  describe '#associated_profiles' do
    context 'when multiple duplicate profiles were found for user' do
      let(:profile3) { create(:profile, :facial_match_proof) }
      let(:duplicate_profile_set) do
        create(
          :duplicate_profile_set,
          profile_ids: [user.active_profile.id, profile2.id, profile3.id],
          service_provider: 'test-sp',
        )
      end

      it 'should return multiple elements and user element' do
        expect(presenter.associated_profiles.count).to eq(3)
      end
    end

    context 'when a single duplicate profiles were found for user' do
      it 'should return user element and other profile' do
        expect(presenter.associated_profiles.count).to eq(2)
      end
    end
  end
end
