require 'rails_helper'

describe PersonalKeyGenerator do
  let(:personal_key) { Base32::Crockford.encode(100**10, length: 16, split: 4).tr('-', ' ') }
  let(:bad_code) { Base32::Crockford.encode(100**9, length: 16, split: 4).tr('-', ' ') }
  let(:invalid_base32_code) { 'four score has letter U in it' }
  let(:generator) { described_class.new(create(:user)) }

  def stub_random_phrase
    random_phrase = instance_double(RandomPhrase)
    allow(random_phrase).to receive(:to_s).and_return(personal_key)
    allow(RandomPhrase).to receive(:new).and_return(random_phrase)
  end

  describe '#create' do
    it 'returns the raw personal key' do
      stub_random_phrase

      expect(generator.create).to eq personal_key.tr(' ', '-')
    end

    it 'hashes the raw personal key' do
      user = create(:user)
      generator = PersonalKeyGenerator.new(user)

      stub_random_phrase

      generator.create

      expect(user.encrypted_recovery_code_digest).to_not eq personal_key
    end

    it 'generates a phrase of 4 words by default' do
      expect(generator.create).to match(/\A\w\w\w\w-\w\w\w\w-\w\w\w\w-\w\w\w\w\z/)
    end

    it 'allows length to be configured via ENV var' do
      allow(Figaro.env).to receive(:recovery_code_length).and_return('14')

      fourteen_letters_and_spaces_start_end_with_letter = /\A(\w+\-){13}\w+\z/
      expect(generator.create).to match(fourteen_letters_and_spaces_start_end_with_letter)
    end

    it 'sets the encrypted recovery code digest' do
      user = create(:user)
      generator = PersonalKeyGenerator.new(user)
      key = generator.create

      expect(user.encrypted_recovery_code_digest).to_not be_empty
      expect(generator.verify(key)).to eq(true)
    end
  end

  describe '#verify' do
    before do
      stub_random_phrase
      generator.create
    end

    it 'returns false for the wrong code' do
      expect(generator.verify(bad_code)).to eq false
    end

    it 'returns false for short code' do
      expect(generator.verify('foo')).to eq false
    end

    it 'returns false for an invalid base32 code' do
      expect(generator.verify(invalid_base32_code)).to eq false
    end

    it 'returns true for the correct code' do
      expect(generator.verify(personal_key)).to eq true
    end

    it 'forgives user mistaking O for 0' do
      expect(generator.verify(personal_key.tr('0', 'o'))).to eq true
    end

    it 'treats case insensitively' do
      expect(generator.verify(personal_key.tr('H', 'h'))).to eq true
    end
  end

  describe '#normalize' do
    before do
      stub_random_phrase
    end

    it 'returns standardized string' do
      expect(generator.normalize(personal_key.downcase)).to eq personal_key
      expect(generator.normalize(personal_key.upcase)).to eq personal_key
      expect(generator.normalize(personal_key.tr(' ', '??????!@#$%)*(&'))).to eq personal_key
    end
  end
end
