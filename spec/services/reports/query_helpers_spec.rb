require 'rails_helper'

RSpec.describe Reports::QueryHelpers do
  include Reports::QueryHelpers

  describe '#quote' do
    it 'quotes dates' do
      expect(quote(Date.new(2021, 1, 1))).to eq(%('2021-01-01'))
    end

    it 'quotes strings to be psql string literals' do
      expect(quote(%(a string with "quotes" in 'the middle'))).
        to eq(%('a string with "quotes" in ''the middle'''))
    end

    it 'quotes arrays as list expressions' do
      expect(quote([1, 2, 3])).to eq('(1, 2, 3)')
    end
  end
end
