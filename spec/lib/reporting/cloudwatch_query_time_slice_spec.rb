require 'rails_helper'
require 'reporting/cloudwatch_query_time_slice'

RSpec.describe Reporting::CloudwatchQueryTimeSlice do
  describe '#self.parse_duration' do
    it 'parses min as minutes' do
      expect(described_class.parse_duration('1111min')).to eq(1111.minutes)
    end

    it 'parses h as hours' do
      expect(described_class.parse_duration('2h')).to eq(2.hours)
    end

    it 'parses d as days' do
      expect(described_class.parse_duration('3d')).to eq(3.days)
    end

    it 'parses w as weeks' do
      expect(described_class.parse_duration('4w')).to eq(4.weeks)
    end

    it 'parses mon as months' do
      expect(described_class.parse_duration('5mon')).to eq(5.months)
    end

    it 'parses y as years' do
      expect(described_class.parse_duration('6y')).to eq(6.years)
    end

    it 'is nil for unknown' do
      expect(described_class.parse_duration('7x')).to be_nil
    end
  end
end
