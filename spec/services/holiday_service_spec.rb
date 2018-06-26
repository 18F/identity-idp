require 'rails_helper'

RSpec.describe HolidayService do
  let(:year) { 2018 }

  let(:instance) { described_class.new(year) }

  context 'instance methods' do
    describe '#holidays' do
      subject { instance.holidays }

      it { is_expected.to eq(holidays) }
    end

    describe '#observed_holidays' do
      subject { instance.observed_holidays }

      it { is_expected.to eq(observed_holidays) }

      context 'when the next NY is on a Saturday' do
        let(:year) { 2010 }

        subject { instance.observed_holidays }

        it 'includes Dec 31st' do
          expect(subject).to include(Date.new(2010, 12, 31))
        end
      end
    end

    describe '#holiday?' do
      subject { instance.holiday?(date) }

      context 'when its a holiday' do
        let(:date) { Date.new(year, 11, 11) }

        it { is_expected.to eq(true) }
      end

      context 'when its not a holiday' do
        let(:date) { Date.new(year, 11, 12) }

        it { is_expected.to eq(false) }
      end
    end

    describe '#observed_holiday?' do
      subject { instance.observed_holiday?(date) }

      context 'when its not a holiday' do
        let(:date) { Date.new(year, 11, 11) }

        it { is_expected.to eq(false) }
      end

      context 'when its a holiday' do
        let(:date) { Date.new(year, 11, 12) }

        it { is_expected.to eq(true) }
      end
    end

    describe '#observed' do
      subject { instance.send(:observed, date) }

      context 'when date is a Saturday' do
        let(:date) { Date.new(2018, 6, 23) }

        it 'returns the day before' do
          expect(subject).to eq(date - 1)
        end
      end

      context 'when date is a Sunday' do
        let(:date) { Date.new(2018, 6, 24) }

        it 'returns the day after' do
          expect(subject).to eq(date + 1)
        end
      end

      context 'when date is a weekday' do
        let(:date) { Date.new(2018, 6, 25) }

        it 'returns the day' do
          expect(subject).to eq(date)
        end
      end
    end
  end

  context 'class methods' do
    describe '.holiday?' do
      subject { described_class.holiday?(date) }

      context 'when its a holiday' do
        let(:date) { Date.new(year, 11, 11) }

        it { is_expected.to eq(true) }
      end

      context 'when its not a holiday' do
        let(:date) { Date.new(year, 11, 12) }

        it { is_expected.to eq(false) }
      end
    end

    describe '.observed_holiday?' do
      subject { described_class.observed_holiday?(date) }

      context 'when its not a holiday' do
        let(:date) { Date.new(year, 11, 11) }

        it { is_expected.to eq(false) }
      end

      context 'when its a holiday' do
        let(:date) { Date.new(year, 11, 12) }

        it { is_expected.to eq(true) }
      end
    end
  end

  def holidays
    [
      Date.new(year, 1, 1),
      Date.new(year, 1, 15),
      Date.new(year, 2, 19),
      Date.new(year, 5, 28),
      Date.new(year, 7, 4),
      Date.new(year, 9, 3),
      Date.new(year, 10, 8),
      Date.new(year, 11, 11),
      Date.new(year, 11, 22),
      Date.new(year, 12, 25),
    ]
  end

  def observed_holidays
    [
      Date.new(year, 1, 1),
      Date.new(year, 1, 15),
      Date.new(year, 2, 19),
      Date.new(year, 5, 28),
      Date.new(year, 7, 4),
      Date.new(year, 9, 3),
      Date.new(year, 10, 8),
      Date.new(year, 11, 12),
      Date.new(year, 11, 22),
      Date.new(year, 12, 25),
    ]
  end
end
