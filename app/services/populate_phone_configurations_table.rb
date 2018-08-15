class PopulatePhoneConfigurationsTable
  def call
    # we don't have a uniqueness constraint in the database to let us blindly insert
    # everything in a single SQL statement. So we have to load by batches and copy
    # over. Much slower, but doesn't duplicate information.
    User.in_batches(of: 1000) { |relation| process_batch(relation) }
  end

  private

  # :reek:FeatureEnvy
  def process_batch(relation)
    User.transaction do
      relation.each do |user|
        next if user.phone_configuration.present? || user.phone.blank?
        user.create_phone_configuration(phone_info_for_user(user))
      end
    end
  end

  def phone_info_for_user(user)
    {
      phone: user.phone,
      confirmed_at: user.phone_confirmed_at,
      delivery_preference: user.otp_delivery_preference,
    }
  end
end
