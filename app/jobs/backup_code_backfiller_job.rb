class BackupCodeBackfillerJob < ApplicationJob
  queue_as :low

  # Helper to be run manually in a Rails console once
  def self.enqueue_all(batch_size: 10_000)
    Range.new(1, User.last.id).
      step(batch_size).
      each do |start|
        perform_later(start_id: start, count: batch_size)
      end
  end

  # Operates on a batch by user, so that we can give a batch
  # the same salt to make forward lookups more efficient
  def perform(start_id:, count:)
    User.
      where('id >= ?', start_id).
      limit(count).
      each do |user|
        perform_batch(user.backup_code_configurations)
      rescue => e
        if Rails.env.production?
          Rails.logger.warn("error converting backup codes for user_id=#{user.id} #{e}")
        else
          raise e
        end
      end
  end

  def perform_batch(backup_code_configurations)
    configs_with_legacy_code = backup_code_configurations.select { |b| b.encrypted_code.present? }

    return if configs_with_legacy_code.empty?

    # @see BackupCodeGenerator#save
    salt = SecureRandom.hex(32)

    configs_with_legacy_code.each do |backup_code_configuration|
      backup_code_configuration.update(
        skip_legacy_encryption: true,
        code_cost: IdentityConfig.store.backup_code_cost,
        code_salt: salt,
        code: backup_code_configuration.code,
      )
    end
  end
end