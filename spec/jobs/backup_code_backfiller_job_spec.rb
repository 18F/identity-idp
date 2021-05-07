require 'rails_helper'

RSpec.describe BackupCodeBackfillerJob do
  describe '.enqueue_all' do
    before do
      User.delete_all
    end

    let!(:users_with_legacy_encryption) do
      3.times.map do
        user = create(:user)
        codes = BackupCodeGenerator.new(user, skip_legacy_encryption: false).create
        OpenStruct.new(user: user, codes: codes)
      end
    end

    let!(:users_without_legacy_encryption) do
      2.times.map do
        user = create(:user)
        codes = BackupCodeGenerator.new(user, skip_legacy_encryption: true).create
        OpenStruct.new(user: user, codes: codes)
      end
    end

    it 'removes legacy encryption, batches salt by user and preserves the findability of codes' do
      users_with_legacy_encryption.each do |user_codes|
        expect(user_codes.user.backup_code_configurations.map(&:encrypted_code)).to all(be_present)
      end

      BackupCodeBackfillerJob.enqueue_all

      (users_with_legacy_encryption + users_without_legacy_encryption).each do |user_codes|
        user = user_codes.user.reload

        expect(user.backup_code_configurations.map(&:encrypted_code)).to all(be_blank)

        salt = user.backup_code_configurations.first.code_salt
        expect(user.backup_code_configurations.map(&:code_salt)).to all(eq(salt))

        code = BackupCodeConfiguration.find_with_code(
          code: user_codes.codes.first,
          user_id: user.id,
        )

        expect(code).to be_present
      end
    end
  end
end
