class PopulatePhoneConfigurationsTable
  def initialize
    @count = 0
    @total = 0
  end

  def call
    # we don't have a uniqueness constraint in the database to let us blindly insert
    # everything in a single SQL statement. So we have to load by batches and copy
    # over. Much slower, but doesn't duplicate information.
    User.in_batches(of: 1000) do |relation| 
      sleep(1)
      process_batch(relation)
      puts "#{@count} / #{@total}"
    end
    puts "Processed #{@count} user phone configurations"
  end

  private

  # :reek:FeatureEnvy
  def process_batch(relation)
    User.transaction do
      relation.each do |user|
        @total += 1
        next if user.phone_configuration.present? || user.encrypted_phone.blank?
        user.create_phone_configuration(phone_info_for_user(user))
        @count += 1
      end
    end
  end

  def phone_info_for_user(user)
    {
      encrypted_phone: user.encrypted_phone,
      confirmed_at: user.phone_confirmed_at,
      delivery_preference: user.otp_delivery_preference,
    }
  end
end
