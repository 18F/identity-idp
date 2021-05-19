require 'rails_helper'

RSpec.describe Reports::MonthHelper do
  include Reports::MonthHelper

  describe '.months' do
    it 'breaks a range into months' do
      expect(months(Date.new(2021, 3, 15)..Date.new(2021, 5, 15))).to eq(
        [
          Date.new(2021, 3, 15)..Date.new(2021, 3, 31),
          Date.new(2021, 4, 1)..Date.new(2021, 4, 30),
          Date.new(2021, 5, 1)..Date.new(2021, 5, 15),
        ],
      )
    end
  end

  describe '.full_month?' do
    it 'is true when the range is a full month' do
      expect(full_month?(Date.new(2021, 1, 1)..Date.new(2021, 1, 31))).to eq(true)
    end

    it 'is false when the range is not a full month' do
      expect(full_month?(Date.new(2021, 1, 2)..Date.new(2021, 1, 30))).to eq(false)
    end
  end
end
