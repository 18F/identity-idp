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

  describe '.without_profanity' do
    it 'keeps executing a block until it does not return something profane' do
      expect(SecureRandom).to receive(:random_number)
        .and_return(
          Base32::Crockford.decode('FART1'),
          Base32::Crockford.decode('FART2'),
          Base32::Crockford.decode('ABCDE'),
        )

      result = ProfanityDetector.without_profanity do
        Base32::Crockford.encode(SecureRandom.random_number(1000))
      end

      expect(result).to eq('ABCDE')
    end

    it 'has a limit to guard against bad random generators' do
      expect do
        ProfanityDetector.without_profanity { 'FART' }
      end.to raise_error('random generator limit')
    end
  end
end
