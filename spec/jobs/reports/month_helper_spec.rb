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
end
