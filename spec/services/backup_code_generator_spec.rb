require 'rails_helper'

RSpec.describe BackupCodeGenerator do
  let(:user) { create(:user) }

  subject(:generator) { BackupCodeGenerator.new(user) }

  it 'should generate backup codes and be able to verify them' do
    codes = generator.create

    codes.each do |code|
      expect(generator.verify(code)).to eq(true)
    end
  end

  it 'generates 12-letter/digit codes via base32 crockford' do
    expect(Base32::Crockford).to receive(:encode).
      and_call_original.at_least(BackupCodeGenerator::NUMBER_OF_CODES).times

    codes = generator.create

    codes.each do |code|
      expect(code).to match(/\A[a-z0-9]{12}\Z/i)
    end
  end

  it 'should reject invalid codes' do
    generator.generate

    success = generator.verify 'This is a string which will never result from code generation'
    expect(success).to be_falsy
  end

  it 'creates codes with the same salt for that batch' do
    generator.create

    salts = user.backup_code_configurations.map(&:code_salt).uniq
    expect(salts.size).to eq(1)
    expect(salts.first).to_not be_empty

    costs = user.backup_code_configurations.map(&:code_cost).uniq
    expect(costs.size).to eq(1)
    expect(costs.first).to_not be_empty
  end

  it 'creates different salts for different batches' do
    user1 = create(:user)
    user2 = create(:user)

    [user1, user2].each { |user| BackupCodeGenerator.new(user).create }

    user1_salt = user1.backup_code_configurations.map(&:code_salt).uniq.first
    user2_salt = user2.backup_code_configurations.map(&:code_salt).uniq.first

    expect(user1_salt).to_not eq(user2_salt)
  end

  it 'filters out profanity' do
    profane = Base32::Crockford.decode('FART')
    not_profane = Base32::Crockford.decode('ABCD')

    expect(SecureRandom).to receive(:random_number).
      and_return(profane, not_profane)

    code = generator.send(:backup_code)

    expect(code).to eq('00000000ABCD')
  end
end
