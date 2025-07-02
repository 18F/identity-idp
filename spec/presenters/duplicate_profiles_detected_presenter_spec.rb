require 'rails_helper'

RSpec.describe DuplicateProfilesDetectedPresenter do
  let(:user) { create(:user, :proofed_with_selfie) }
  let(:user_session) { {} }
  let(:presenter) { described_class.new(user: user, user_session: user_session) }
  let(:profile2) { create(:profile, :facial_match_proof) }

  describe '#duplicate_profiles' do
    context 'when multiple duplicate profiles were found for user' do
      let(:profile3) { create(:profile, :facial_match_proof) }
      before do
        user_session[:duplicate_profile_ids] = [profile2.id, profile3.id]
      end

      it 'should return multiple elements' do
        expect(presenter.duplicate_profiles.count).to eq(2)
      end
    end

    context 'when a single duplicate profiles were found for user' do
      before do
        user_session[:duplicate_profile_ids] = [profile2.id]
      end
      it 'should return singular element' do
        expect(presenter.duplicate_profiles.count).to eq(1)
      end
    end
  end

  describe '#recognize_all_profiles' do
    context 'when multiple duplicate profiles were found for user' do
      let(:profile3) { create(:profile, :facial_match_proof) }

      before do
        user_session[:duplicate_profile_ids] = [profile2.id, profile3.id]
      end

      it 'should return plural text' do
        expect(presenter.recognize_all_profiles)
          .to eq(I18n.t('duplicate_profiles_detected.yes_many'))
      end
    end

    context 'when a single duplicate profiles were found for user' do
      before do
        user_session[:duplicate_profile_ids] = [profile2.id]
      end
      it 'should return singular text' do
        expect(presenter.recognize_all_profiles)
          .to eq(I18n.t('duplicate_profiles_detected.yes_single'))
      end
    end
  end

  describe '#dont_recognize_some_profiles' do
    context 'when multiple duplicate profiles were found for user' do
      let(:profile3) { create(:profile, :facial_match_proof) }

      before do
        user_session[:duplicate_profile_ids] = [profile2.id, profile3.id]
      end

      it 'should return multiple text' do
        expect(presenter.dont_recognize_some_profiles)
          .to eq(I18n.t('duplicate_profiles_detected.no_recognize_many'))
      end
    end

    context 'when a single duplicate profiles were found for user' do
      before do
        user_session[:duplicate_profile_ids] = [profile2.id]
      end

      it 'should return singular text' do
        expect(presenter.dont_recognize_some_profiles)
          .to eq(I18n.t('duplicate_profiles_detected.no_recognize_single'))
      end
    end
  end
end
