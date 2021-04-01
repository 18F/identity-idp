require 'rails_helper'

RSpec.describe BackupCodeBenchmarker do
  let(:logger) { Logger.new('/dev/null') }

  let(:num_rows) { 4 }
  let(:num_per_user) { 2 }
  let(:user) { build(:user) }
  subject(:benchmarker) do
    BackupCodeBenchmarker.new(
      cost: '4000$8$4$',
      logger: logger,
      num_rows: num_rows,
      num_per_user: num_per_user,
      batch_size: 10,
    )
  end

  describe '#run' do
    context 'in production' do
      before do
        expect(Identity::Hostdata).to receive(:env).and_return('prod')
      end

      it 'bails and does not run' do
        expect { benchmarker.run }.to raise_error('do not run in prod')
      end
    end

    context 'when enough backup code configurations already exist' do
      let(:num_rows) { 2 }

      before do
        num_rows.times { create(:backup_code_configuration, user: user) }
      end

      it 'does not create any new ones' do
        expect { benchmarker.run }.to_not(change { BackupCodeConfiguration.count })
      end
    end

    it 'sets scrypted value' do
      BackupCodeConfiguration.delete_all

      benchmarker.run

      expect(BackupCodeConfiguration.count).to eq(num_rows)

      BackupCodeConfiguration.all.each do |cfg|
        expect(cfg.salted_code_fingerprint).to eq(
          benchmarker.scrypt_password_digest(
            password: cfg.code,
            salt: cfg.code_salt,
            cost: cfg.code_cost,
          ),
        )
      end
    end

    it 'does not update beyond num_rows' do
      (num_rows + 1).times { create(:backup_code_configuration, user: user) }

      expect { benchmarker.run }.
        to_not(change { BackupCodeConfiguration.last.salted_code_fingerprint })
    end
  end
end
