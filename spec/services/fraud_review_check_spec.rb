require 'rails_helper'

RSpec.describe FraudReviewChecker do
  subject { described_class.new(user) }

  describe '#fraud_check_failed?' do
    context 'the user is not fraud review pending or rejected' do
      let(:user) { create(:user) }

      it { expect(subject.fraud_check_failed?).to eq(false) }
    end

    context 'the user is fraud review pending' do
      let(:user) { create(:user, :fraud_review_pending) }

      it { expect(subject.fraud_check_failed?).to eq(true) }
    end

    context 'the user is fraud review rejected' do
      let(:user) { create(:user, :fraud_rejection) }

      it { expect(subject.fraud_check_failed?).to eq(true) }
    end
  end

  describe '#fraud_review_pending?' do
    context 'the user is not fraud review pending or rejected' do
      let(:user) { create(:user) }

      it { expect(subject.fraud_review_pending?).to eq(false) }
    end

    context 'the user is fraud review pending' do
      let(:user) { create(:user, :fraud_review_pending) }

      it { expect(subject.fraud_review_pending?).to eq(true) }
    end

    context 'the user is fraud review rejected' do
      let(:user) { create(:user, :fraud_rejection) }

      it { expect(subject.fraud_review_pending?).to eq(false) }
    end
  end

  describe '#fraud_rejection?' do
    context 'the user is not fraud review pending or rejected' do
      let(:user) { create(:user) }

      it { expect(subject.fraud_rejection?).to eq(false) }
    end

    context 'the user is fraud review pending' do
      let(:user) { create(:user, :fraud_review_pending) }

      it { expect(subject.fraud_rejection?).to eq(false) }
    end

    context 'the user is fraud review rejected' do
      let(:user) { create(:user, :fraud_rejection) }

      it { expect(subject.fraud_rejection?).to eq(true) }
    end
  end

  describe '#fraud_review_eligible?' do
    context 'the user is not fraud review pending or rejected' do
      let(:user) { create(:user) }

      it { expect(subject.fraud_review_eligible?).to eq(false) }
    end

    context 'the user is fraud review pending for less than 30 days' do
      let(:user) { create(:user, :fraud_review_pending) }

      it { expect(subject.fraud_review_eligible?).to eq(true) }
    end

    context 'the user is fraud review pending for more than 30 days' do
      let(:user) do
        record = create(:user, :fraud_review_pending)
        record.fraud_review_pending_profile.update!(fraud_review_pending_at: 31.days.ago)
        record
      end

      it { expect(subject.fraud_review_eligible?).to eq(false) }
    end

    context 'the user is fraud review rejected' do
      let(:user) { create(:user, :fraud_rejection) }

      it { expect(subject.fraud_review_eligible?).to eq(false) }
    end

    context 'fraud review is pending for passed ipp enrollment' do
      let(:user) { create(:user) }
      let!(:profile) { create(:profile, fraud_review_pending_at: 1.day.ago, user: user) }
      let!(:enrollment) { create(:in_person_enrollment, :passed, user: user, profile: profile) }

      it { expect(subject.ipp_fraud_review_pending?).to eq(true) } 
    end
    
    context 'fraud review is pending for non-passed ipp enrollment' do
      let(:user) { create(:user) }
      let!(:profile) { create(:profile, fraud_review_pending_at: 1.day.ago, user: user) }
      let!(:enrollment) { create(:in_person_enrollment, :establishing, user: user, profile: profile) }

      it 'returns false' do 
        expect(subject.ipp_fraud_review_pending?).to eq(false)
      end
    end

  end
end
