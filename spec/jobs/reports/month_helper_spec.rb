require 'rails_helper'

RSpec.describe Reports::MonthHelper do
  include Reports::MonthHelper

  describe '.months' do
    it 'breaks a range into months as utc timestamps from beginning to end of day' do
      expect(months(Date.new(2021, 3, 15)..Date.new(2021, 5, 15))).to eq(
        [
          Range.new(
            Date.new(2021, 3, 15).in_time_zone('UTC').beginning_of_day,
            Date.new(2021, 3, 31).in_time_zone('UTC').end_of_day,
          ),
          Range.new(
            Date.new(2021, 4, 1).in_time_zone('UTC').beginning_of_day,
            Date.new(2021, 4, 30).in_time_zone('UTC').end_of_day,
          ),
          Range.new(
            Date.new(2021, 5, 1).in_time_zone('UTC').beginning_of_day,
            Date.new(2021, 5, 14).in_time_zone('UTC').end_of_day,
          ),
        ],
      )
    end
  end
end
