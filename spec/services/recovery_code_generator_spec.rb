require 'rails_helper'

describe RecoveryCodeGenerator do
  describe '#create' do
    it 'returns the raw recovery code' do
      generator = RecoveryCodeGenerator.new(User.new)

      allow(SecureRandom).to receive(:hex).with(8).and_return('a1b2c3d4e5f6g7h8')

      expect(generator.create).to eq 'a1b2c3d4e5f6g7h8'
    end

    it 'hashes the raw recovery code' do
      user = create(:user)

      generator = RecoveryCodeGenerator.new(user)

      allow(SecureRandom).to receive(:hex).with(8).and_return('a1b2c3d4e5f6g7h8')

      generator.create

      expect(user.recovery_code).to_not eq 'a1b2c3d4e5f6g7h8'
    end

    it 'generates an alphanumeric string of length 16 by default' do
      generator = RecoveryCodeGenerator.new(User.new)

      expect(generator.create).to match(/\A[a-zA-Z0-9]{16}\z/)
    end

    it 'allows length to be configured via ENV var' do
      allow(Figaro.env).to receive(:recovery_code_length).and_return('14')
      generator = RecoveryCodeGenerator.new(User.new)

      expect(generator.create).to match(/\A[a-zA-Z0-9]{14}\z/)
    end
  end

  describe '#valid?' do
    it 'validates the raw recovery code against what is stored for the User' do
      user = create(:user)
      generator = RecoveryCodeGenerator.new(user)
      raw_code = generator.create

      generator2 = RecoveryCodeGenerator.new(user)

      expect(generator2.valid?(raw_code)).to eq true
    end
  end
end
