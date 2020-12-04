require 'rails_helper'

RSpec.describe IsWeekendOrHoliday do
  let(:subject) { described_class }

  let(:a_monday) { Date.new(2020, 11, 23) }
  let(:a_friday) { Date.new(2020, 11, 27) }
  let(:a_saturday) { Date.new(2020, 11, 28) }
  let(:a_sunday) { Date.new(2020, 11, 29) }
  let(:a_thanksgiving) { Date.new(2020, 11, 26) }

  describe '#call' do
    it 'returns true for weekends' do
      expect(subject.call(a_saturday)).to eq(true)
      expect(subject.call(a_sunday)).to eq(true)
    end

    it 'returns false for weekdays' do
      expect(subject.call(a_monday)).to eq(false)
      expect(subject.call(a_friday)).to eq(false)
    end

    it 'returns true for holidays on a weekday' do
      expect(subject.call(a_thanksgiving)).to eq(true)
    end
  end
end
