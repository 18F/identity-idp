# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Idv::SsnEditDistanceCalculator do
  describe '#calculate' do
    context 'two strings are equal' do
      it 'returns 0' do
        result = Idv::SsnEditDistanceCalculator.new('900-12-3456', '900-12-3456').compute
        expect(result).to eql(0)
      end
    end

    context 'two strings are different' do
      it 'returns correct edit distance' do
        result = Idv::SsnEditDistanceCalculator.new('900-11-3456', '900-12-3456').compute
        expect(result).to eql(1)
      end
    end

    context 'the strings have different lengths' do
      it 'returns the edit distance for the shortest string' do
        result = Idv::SsnEditDistanceCalculator.new('900-11-1256', '900-12-12').compute
        expect(result).to eql(1)
      end
    end
  end
end
