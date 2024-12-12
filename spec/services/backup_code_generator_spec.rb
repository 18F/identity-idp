require 'rails_helper'

RSpec.describe BackupCodeGenerator do
  let(:user) { create(:user) }

  subject(:generator) { BackupCodeGenerator.new(user) }

  describe '#delete_and_regenerate' do
    subject(:codes) { generator.delete_and_regenerate }

    it 'generates backup codes' do
      expect { codes }
        .to change { user.reload.backup_code_configurations.count }
        .from(0)
        .to(BackupCodeGenerator::NUMBER_OF_CODES)
    end

    it 'returns valid 12-character codes via base32 crockford' do
      expect(Base32::Crockford).to receive(:encode)
        .and_call_original.at_least(BackupCodeGenerator::NUMBER_OF_CODES).times

      expect(codes).to be_present
      codes.each do |code|
        expect(code).to match(/\A[a-z0-9]{12}\Z/i)
        expect(generator.if_valid_consume_code_return_config_created_at(code)).not_to eq(nil)
      end
    end

    it 'should generate backup codes and be able to verify them' do
      codes.each do |code|
        expect(generator.if_valid_consume_code_return_config_created_at(code)).not_to eq(nil)
      end
    end

    it 'creates codes with the same salt for that batch' do
      codes

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

      [user1, user2].each { |user| BackupCodeGenerator.new(user).delete_and_regenerate }

      user1_salt = user1.backup_code_configurations.map(&:code_salt).uniq.first
      user2_salt = user2.backup_code_configurations.map(&:code_salt).uniq.first

      expect(user1_salt).to_not eq(user2_salt)
    end

    it 'filters out profanity' do
      profane = Base32::Crockford.decode('FART')
      not_profane = Base32::Crockford.decode('ABCD')

      expect(SecureRandom).to receive(:random_number)
        .and_return(profane, not_profane)

      code = generator.send(:backup_code)

      expect(code).to eq('00000000ABCD')
    end
  end

  describe '#if_valid_consume_code_return_config_created_at' do
    let(:code) {}
    subject(:result) { generator.if_valid_consume_code_return_config_created_at(code) }

    context 'invalid code' do
      let(:code) { 'invalid' }

      it { is_expected.to eq(nil) }
    end

    context 'nil code' do
      let(:code) { 'invalid' }

      it { is_expected.to eq(nil) }
    end

    context 'valid code' do
      let(:code) { generator.delete_and_regenerate.sample }

      it { is_expected.to be_instance_of(Time) }
    end
  end
end
