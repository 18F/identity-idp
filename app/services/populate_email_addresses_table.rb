class PopulateEmailAddressesTable
  def initialize
    @count = 0
    @total = 0
  end

  # :reek:DuplicateMethodCall
  def call
    User.in_batches(of: 1000) do |relation|
      sleep(1)
      process_batch(relation)
      Rails.logger.info "#{@count} / #{@total}"
    end
    Rails.logger.info "Processed #{@count} user email addresses"
  end

  private

  # :reek:DuplicateMethodCall
  def process_batch(relation)
    User.transaction do
      relation.each do |user|
        @total += 1
        next if user.email_addresses.any? || user.encrypted_email.blank?
        user.email_addresses.create(email_info_for_user(user))
        @count += 1
      end
    end
  end

  def email_info_for_user(user)
    {
      encrypted_email: user.encrypted_email,
      email_fingerprint: user.email_fingerprint,
      confirmed_at: user.confirmed_at,
      confirmation_sent_at: user.confirmation_sent_at,
      confirmation_token: user.confirmation_token,
    }
  end
end
