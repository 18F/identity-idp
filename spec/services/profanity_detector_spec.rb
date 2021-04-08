require 'rails_helper'

RSpec.describe ProfanityDetector do
  describe '.profane?' do
    it 'is false for benign words' do
      expect(ProfanityDetector.profane?('abdef')).to eq(false)
    end

    it 'detects profanity' do
      expect(ProfanityDetector.profane?('fart')).to eq(true)
    end

    it 'detects profanity across upper/lower case' do
      expect(ProfanityDetector.profane?('fart')).to eq(true)
      expect(ProfanityDetector.profane?('FART')).to eq(true)
      expect(ProfanityDetector.profane?('fArT')).to eq(true)
    end

    it 'detects profanity inside words' do
      expect(ProfanityDetector.profane?('some emfartic sentence')).to eq(true)
    end

    it 'detects profanity split by dashes' do
      expect(ProfanityDetector.profane?('abFA-RTcd')).to eq(true)
    end
  end
end
