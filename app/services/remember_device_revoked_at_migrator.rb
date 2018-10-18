class RememberDeviceRevokedAtMigrator
  def initialize
    @batch = 1
    @count = 0
    @total = 0
  end

  # :reek:DuplicateMethodCall
  def call
    User.includes(:phone_configurations).in_batches(of: 1000) do |relation|
      sleep(1)
      Rails.logger.info "Processing batch #{@batch}"
      process_batch(relation)
    end
    Rails.logger.info "Processed #{@count} / #{@total} users"
  end

  private

  def process_batch(relation)
    User.transaction do
      relation.each do |user|
        update_revoked_at_date(user)
      end
    end
    @batch += 1
  end

  # :reek:FeatureEnvy
  def update_revoked_at_date(user)
    @total += 1
    phone_configurations = user.phone_configurations
    return if phone_configurations.empty?

    revoked_at_date = phone_configurations.pluck(:confirmed_at).max
    user.update!(remember_device_revoked_at: revoked_at_date)
    @count += 1
  end
end
