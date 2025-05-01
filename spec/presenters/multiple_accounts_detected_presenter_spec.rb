require 'rails_helper'

RSpec.describe MultipleAccountsDetectedPresenter do
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

  describe '#other_accounts_detected' do
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

      it 'should return multiple elements' do
        expect(presenter.other_accounts_detected.count).to eq(2)
      end
    end

    context 'when a single duplicate profiles were found for user' do
      it 'should return singular element' do
        expect(presenter.other_accounts_detected.count).to eq(1)
      end
    end
  end

  describe '#recognize_all_accounts' do
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

      it 'should return plural text' do
        expect(presenter.recognize_all_accounts)
          .to eq(I18n.t('multiple_accounts_detected.yes_many'))
      end
    end

    context 'when a single duplicate profiles were found for user' do
      it 'should return singular text' do
        expect(presenter.recognize_all_accounts)
          .to eq(I18n.t('multiple_accounts_detected.yes_single'))
      end
    end
  end

  describe '#dont_recognize_some_accounts' do
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

      it 'should return multiple text' do
        expect(presenter.dont_recognize_some_accounts)
          .to eq(I18n.t('mutliple_accounts_detected.no_recognize_many'))
      end
    end

    context 'when a single duplicate profiles were found for user' do
      it 'should return singular text' do
        expect(presenter.dont_recognize_some_accounts)
          .to eq(I18n.t('mutliple_accounts_detected.no_recognize_single'))
      end
    end
  end
end
