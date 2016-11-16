require 'rails_helper'

describe RecoveryCodeGenerator do
  let(:recovery_code) { 'a1b2c3d4e5f6g7h8' }

  describe '#create' do
    it 'returns the raw recovery code' do
      user = create(:user)
      generator = RecoveryCodeGenerator.new(user)

      allow(SecureRandom).to receive(:hex).with(8).and_return(recovery_code)

      expect(generator.create).to eq recovery_code
    end

    it 'hashes the raw recovery code' do
      user = create(:user)
      generator = RecoveryCodeGenerator.new(user)

      allow(SecureRandom).to receive(:hex).with(8).and_return(recovery_code)

      generator.create

      expect(user.recovery_code).to_not eq recovery_code
    end

    it 'generates an alphanumeric string of length 16 by default' do
      user = create(:user)
      generator = RecoveryCodeGenerator.new(user)

      expect(generator.create).to match(/\A[a-zA-Z0-9]{16}\z/)
    end

    it 'allows length to be configured via ENV var' do
      user = create(:user)
      allow(Figaro.env).to receive(:recovery_code_length).and_return('14')
      generator = RecoveryCodeGenerator.new(user)

      expect(generator.create).to match(/\A[a-zA-Z0-9]{14}\z/)
    end
  end

  describe '#verify' do
    before do
      allow(SecureRandom).to receive(:hex).with(8).and_return(recovery_code)
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
