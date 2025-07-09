require 'rails_helper'

RSpec.describe DuplicateProfilesDetectedPresenter do
  let(:user) { create(:user, :proofed_with_selfie) }
  let(:user_session) { {} }
  let(:presenter) { described_class.new(user: user, user_session: user_session) }
  let(:profile2) { create(:profile, :facial_match_proof) }

  describe '#associated_profiles' do
    context 'when multiple duplicate profiles were found for user' do
      let(:profile3) { create(:profile, :facial_match_proof) }
      before do
        user_session[:duplicate_profile_ids] = [profile2.id, profile3.id]
      end

      it 'should return multiple elements and user element' do
        expect(presenter.associated_profiles.count).to eq(3)
      end
    end

    context 'when a single duplicate profiles were found for user' do
      before do
        user_session[:duplicate_profile_ids] = [profile2.id]
      end
      it 'should return user element and other profile' do
        expect(presenter.associated_profiles.count).to eq(2)
      end
    end
  end
end
