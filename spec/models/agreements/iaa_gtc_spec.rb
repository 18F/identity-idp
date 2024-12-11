require 'rails_helper'

RSpec.describe Agreements::IaaGtc, type: :model do
  describe 'validations and associations' do
    subject { create(:iaa_gtc) }

    it { is_expected.to validate_presence_of(:gtc_number) }
    it { is_expected.to validate_uniqueness_of(:gtc_number) }
    it { is_expected.to validate_presence_of(:mod_number) }
    it do
      is_expected.to validate_numericality_of(:mod_number)
        .only_integer
        .is_greater_than_or_equal_to(0)
    end
    it do
      is_expected.to validate_numericality_of(:estimated_amount)
        .is_less_than(10_000_000_000)
        .is_greater_than_or_equal_to(0)
        .allow_nil
    end
    it { is_expected.to validate_presence_of(:start_date) }
    it { is_expected.to validate_presence_of(:end_date) }
    it 'validates that the end_date must be after the start_date' do
      subject.end_date = subject.start_date - 1.day
      expect(subject).not_to be_valid
    end

    it { is_expected.to belong_to(:partner_account) }

    it { is_expected.to have_many(:iaa_orders).dependent(:restrict_with_exception) }
  end

  describe '#status' do
    it 'returns "pending_start" if the agreement is not yet in force' do
      gtc = build(:iaa_gtc, start_date: Time.zone.tomorrow)
      expect(gtc.status).to eq('pending_start')
    end
    it 'returns "expired" if the agreement is no longer in force' do
      gtc = build(:iaa_gtc, start_date: Time.zone.today - 1.year, end_date: Time.zone.yesterday)
      expect(gtc.status).to eq('expired')
    end
    it 'returns "active" if the agreement is in force' do
      gtc = build(:iaa_gtc, start_date: Time.zone.yesterday, end_date: Time.zone.tomorrow)
      expect(gtc.status).to eq('active')
    end
  end
end
