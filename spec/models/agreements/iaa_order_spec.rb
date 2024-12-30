require 'rails_helper'

RSpec.describe Agreements::IaaOrder, type: :model do
  describe 'validations and associations' do
    subject { create(:iaa_order) }

    it { is_expected.to validate_presence_of(:order_number) }
    it { is_expected.to validate_uniqueness_of(:order_number).scoped_to(:iaa_gtc_id) }
    it do
      is_expected.to validate_numericality_of(:order_number)
        .only_integer
        .is_greater_than_or_equal_to(0)
    end
    it { is_expected.to validate_presence_of(:mod_number) }
    it do
      is_expected.to validate_numericality_of(:mod_number)
        .only_integer
        .is_greater_than_or_equal_to(0)
    end
    it { is_expected.to validate_presence_of(:pricing_model) }
    it do
      is_expected.to validate_numericality_of(:pricing_model)
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

    it { is_expected.to belong_to(:iaa_gtc) }

    it { is_expected.to have_one(:partner_account).through(:iaa_gtc) }
    it { is_expected.to have_many(:integration_usages).dependent(:restrict_with_exception) }
    it { is_expected.to have_many(:integrations).through(:integration_usages) }
  end

  describe '#status' do
    it 'returns "pending_start" if the agreement is not yet in force' do
      order = build(:iaa_order, start_date: Time.zone.tomorrow)
      expect(order.status).to eq('pending_start')
    end
    it 'returns "expired" if the agreement is no longer in force' do
      order = build(:iaa_order, start_date: Time.zone.today - 1.year, end_date: Time.zone.yesterday)
      expect(order.status).to eq('expired')
    end
    it 'returns "active" if the agreement is in force' do
      order = build(:iaa_order, start_date: Time.zone.yesterday, end_date: Time.zone.tomorrow)
      expect(order.status).to eq('active')
    end
  end

  describe '#in_pop?' do
    let(:order) do
      build(
        :iaa_order,
        start_date: Time.zone.today,
        end_date: Time.zone.today + 1.week,
      )
    end

    it 'raises an argument error if a non-date/datetime is passed in' do
      expect { order.in_pop?('foo') }.to raise_error(ArgumentError)
    end
    it 'returns false if the start_date is nil' do
      order.start_date = nil
      expect(order.in_pop?(Time.zone.today + 1.day)).to be false
    end
    it 'returns false if the end_date is nil' do
      order.end_date = nil
      expect(order.in_pop?(Time.zone.today + 1.day)).to be false
    end
    it 'returns false if the date is outside the POP' do
      expect(order.in_pop?(Time.zone.today - 1.day)).to be false
    end
    it 'returns true if the date is within the POP' do
      expect(order.in_pop?(Time.zone.today + 1.day)).to be true
    end
  end
end
