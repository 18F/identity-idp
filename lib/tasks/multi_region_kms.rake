namespace :multi_region_kms do
  desc 'Confirm that the multi-region KMS inner-layers are the same for both ciphertexts'
  task check_inner_layer: :environment do |_task, _args|
    ActiveRecord::Base.connection.execute('SET statement_timeout = 60000')

    sample_password_users =
      User.where.not(encrypted_password_digest_multi_region: nil).limit(10000).all
    sample_personal_key_users =
      User.where.not(encrypted_recovery_code_digest_multi_region: nil).limit(10000).all
    sample_profiles = Profile.where.not(encrypted_pii_multi_region: nil).limit(10000).all

    kms_client = Encryption::KmsClient.new

    mismatched_records = []

    sample_password_users.each do |user|
      kms_context = {
        'context' => 'password-digest',
        'user_uuid' => user.uuid,
      }

      mr_inner_layer = kms_client.decrypt(
        JSON.parse(user.encrypted_password_digest_multi_region)['encrypted_password'], kms_context
      )
      sr_inner_layer = kms_client.decrypt(
        JSON.parse(user.encrypted_password_digest)['encrypted_password'], kms_context
      )

      if mr_inner_layer != sr_inner_layer
        warn "Mismatch identified: User##{user.id}"
        mismatched_records.push(user)
      end
    end

    sample_personal_key_users.each do |user|
      kms_context = {
        'context' => 'password-digest',
        'user_uuid' => user.uuid,
      }

      mr_inner_layer = kms_client.decrypt(
        JSON.parse(user.encrypted_recovery_code_digest_multi_region)['encrypted_password'],
        kms_context,
      )
      sr_inner_layer = kms_client.decrypt(
        JSON.parse(user.encrypted_recovery_code_digest)['encrypted_password'], kms_context
      )

      if mr_inner_layer != sr_inner_layer
        warn "Mismatch identified: User##{user.id}"
        mismatched_records.push(user)
      end
    end

    sample_profiles.each do |profile|
      kms_context = {
        'context' => 'pii-encryption',
        'user_uuid' => profile.user.uuid,
      }

      mr_pii_inner_layer = kms_client.decrypt(
        Base64.decode64(JSON.parse(profile.encrypted_pii_multi_region)['encrypted_data']),
        kms_context,
      )
      sr_pii_inner_layer = kms_client.decrypt(
        Base64.decode64(JSON.parse(profile.encrypted_pii)['encrypted_data']),
        kms_context,
      )
      mr_pii_recovery_inner_layer = kms_client.decrypt(
        Base64.decode64(JSON.parse(profile.encrypted_pii_recovery_multi_region)['encrypted_data']),
        kms_context,
      )
      sr_pii_recovery_inner_layer = kms_client.decrypt(
        Base64.decode64(JSON.parse(profile.encrypted_pii_recovery)['encrypted_data']),
        kms_context,
      )

      mistmatch_detected = mr_pii_inner_layer != sr_pii_inner_layer ||
                           mr_pii_recovery_inner_layer != sr_pii_recovery_inner_layer

      if mistmatch_detected
        warn "Mismatch identified: Profile##{profile.id}"
        mismatched_records.push(profile)
      end
    end

    warn "Sampled #{sample_password_users.size} passwords"
    warn "Sampled #{sample_personal_key_users.size} personal keys"
    warn "Sampled #{sample_profiles.size} encrypted PII records"
    warn "#{mismatched_records.size} mismatched records detected"
  end
end
