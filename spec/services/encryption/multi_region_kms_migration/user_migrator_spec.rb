require 'rails_helper'

RSpec.describe Encryption::MultiRegionKmsMigration::UserMigrator do
  let(:user) { create(:user, password: 'salty pickles', personal_key: '1234-ABCD') }

  subject { described_class.new(user) }

  describe '#migrate!' do
    context 'for a user with a single-region password digest' do
      let(:user) do
        record = super()
        record.update!(encrypted_password_digest_multi_region: nil)
        record
      end

      it 'migrates the ciphertext' do
        subject.migrate!

        expect_ciphertext_to_be_migrated(
          single_region_ciphertext: user.reload.encrypted_password_digest,
          multi_region_ciphertext: user.encrypted_password_digest_multi_region,
          password: user.password,
          user_uuid: user.uuid,
        )
      end
    end

    context 'for a user with a blank password digest' do
      let(:user) do
        record = super()
        record.update!(
          encrypted_password_digest: '',
          encrypted_password_digest_multi_region: '',
        )
        record
      end

      it 'does not try to migrate the password digest' do
        subject.migrate!

        expect(user.reload.encrypted_password_digest_multi_region).to eq('')
      end
    end

    context 'for a user with a nil password digest' do
      let(:user) do
        record = super()
        record.update!(
          encrypted_password_digest: nil,
          encrypted_password_digest_multi_region: nil,
        )
        record
      end

      it 'does not try to migrate the password digest' do
        subject.migrate!

        expect(user.reload.encrypted_password_digest_multi_region).to be_nil
      end
    end

    context 'for a user with a password that has already been migrated' do
      it 'does not modify the multi-region digest' do
        original_multi_region_password_digest = user.encrypted_password_digest_multi_region

        subject.migrate!

        expect(user.reload.encrypted_password_digest_multi_region).to eq(
          original_multi_region_password_digest,
        )
      end
    end

    context 'for a user with a single-region recovery code digest' do
      let(:user) do
        record = super()
        record.update!(encrypted_recovery_code_digest_multi_region: nil)
        record
      end

      it 'migrates the ciphertext' do
        subject.migrate!

        expect_ciphertext_to_be_migrated(
          single_region_ciphertext: user.reload.encrypted_recovery_code_digest,
          multi_region_ciphertext: user.encrypted_recovery_code_digest_multi_region,
          password: user.personal_key,
          user_uuid: user.uuid,
        )
      end
    end

    context 'for a user with a blank recovery code digest' do
      let(:user) do
        record = super()
        record.update!(
          encrypted_recovery_code_digest: '',
          encrypted_recovery_code_digest_multi_region: '',
        )
        record
      end

      it 'does not try to migrate the password digest' do
        subject.migrate!

        expect(user.reload.encrypted_recovery_code_digest_multi_region).to eq('')
      end
    end

    context 'for a user with a nil recovery code digest' do
      let(:user) do
        record = super()
        record.update!(
          encrypted_recovery_code_digest: nil,
          encrypted_recovery_code_digest_multi_region: nil,
        )
        record
      end

      it 'does not try to migrate the password digest' do
        subject.migrate!

        expect(user.reload.encrypted_recovery_code_digest_multi_region).to be_nil
      end
    end

    context 'for a user with a recovery code that has already been migrated' do
      it 'does not modify the multi-region digest' do
        original_multi_region_recovery_code_digest =
          user.encrypted_recovery_code_digest_multi_region

        subject.migrate!

        expect(user.reload.encrypted_recovery_code_digest_multi_region).to eq(
          original_multi_region_recovery_code_digest,
        )
      end
    end
  end

  def expect_ciphertext_to_be_migrated(
    single_region_ciphertext:,
    multi_region_ciphertext:,
    password:,
    user_uuid:
  )
    password_verifier = Encryption::PasswordVerifier.new
    single_region_digest_pair = Encryption::RegionalCiphertextPair.new(
      single_region_ciphertext: single_region_ciphertext, multi_region_ciphertext: nil,
    )
    multi_region_digest_pair = Encryption::RegionalCiphertextPair.new(
      single_region_ciphertext: nil, multi_region_ciphertext: multi_region_ciphertext,
    )

    aggregate_failures do
      expect(
        password_verifier.verify(digest_pair: single_region_digest_pair, user_uuid:, password:),
      ).to eq(true)
      expect(
        password_verifier.verify(digest_pair: multi_region_digest_pair, user_uuid:, password:),
      ).to eq(true)
    end
  end
end
