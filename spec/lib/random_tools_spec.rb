require 'rails_helper'

RSpec.describe Upaya::RandomTools do
  describe '#random_weighted_sample' do
    it 'raises ArgumentError given empty choices' do
      expect {
        Upaya::RandomTools.random_weighted_sample({})
      }.to raise_error(ArgumentError, /empty choices/)
    end

    it 'handles equal weights -- 0' do
      expect(Upaya::RandomTools).to receive(:rand).with(2).and_return(0)
      input = { A: 1, B: 1 }
      expect(Upaya::RandomTools.random_weighted_sample(input)).to eq :A
    end
    it 'handles equal weights -- 1' do
      expect(Upaya::RandomTools).to receive(:rand).with(2).and_return(1)
      input = { A: 1, B: 1 }
      expect(Upaya::RandomTools.random_weighted_sample(input)).to eq :B
    end

    it 'handles complex weights' do
      input = { A: 1, B: 1, C: 4, D: 2, E: 2 }
      [
        [0, :A],
        [1, :B],
        [2, :C],
        [3, :C],
        [4, :C],
        [5, :C],
        [6, :D],
        [7, :D],
        [8, :E],
        [9, :E],
      ].each do |rand_result, expected_return_value|
        expect(Upaya::RandomTools).to receive(:rand).with(10).and_return(rand_result)
        expect(Upaya::RandomTools.random_weighted_sample(input)).to eq expected_return_value
      end
    end

    it 'rejects non-integer weights' do
      expect {
        Upaya::RandomTools.random_weighted_sample(a: 1.5)
      }.to raise_error(ArgumentError, /integer/)
    end

    it 'rejects negative weights' do
      expect {
        Upaya::RandomTools.random_weighted_sample(a: 10, b: -1)
      }.to raise_error(ArgumentError, />= 0/)
    end

    it 'rejects weights sum to zero' do
      expect {
        Upaya::RandomTools.random_weighted_sample(a: 0)
      }.to raise_error(ArgumentError, /non-zero/)
    end
  end
end
