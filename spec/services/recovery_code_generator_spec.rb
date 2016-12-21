require 'rails_helper'

describe RecoveryCodeGenerator do
  let(:recovery_code) { 'four score and seven years' }

  def stub_random_phrase
    random_phrase = instance_double(RandomPhrase)
    allow(random_phrase).to receive(:to_s).and_return(recovery_code)
    allow(RandomPhrase).to receive(:new).and_return(random_phrase)
  end

  describe '#create' do
    it 'returns the raw recovery code' do
      user = create(:user)
      generator = RecoveryCodeGenerator.new(user)

      stub_random_phrase

      expect(generator.create).to eq recovery_code
    end

    it 'hashes the raw recovery code' do
      user = create(:user)
      generator = RecoveryCodeGenerator.new(user)

      stub_random_phrase

      generator.create

      expect(user.recovery_code).to_not eq recovery_code
    end

    it 'generates a phrase of 5 words by default' do
      user = create(:user)
      generator = RecoveryCodeGenerator.new(user)

      expect(generator.create).to match(/\A(\w+\ ){4}\w+\z/)
    end

    it 'allows length to be configured via ENV var' do
      user = create(:user)
      allow(Figaro.env).to receive(:recovery_code_length).and_return('14')
      generator = RecoveryCodeGenerator.new(user)

      expect(generator.create).to match(/\A(\w+\ ){13}\w+\z/)
    end
  end

  describe '#verify' do
    before do
      stub_random_phrase
    end

    it 'returns false for the wrong code' do
      user = create(:user)
      generator = RecoveryCodeGenerator.new(user)
      generator.create

      expect(generator.verify('not the real recovery code')).to eq false
    end

    it 'returns true for the correct code' do
      user = create(:user)
      generator = RecoveryCodeGenerator.new(user)
      generator.create

      expect(generator.verify(recovery_code)).to eq true
    end
  end
end
