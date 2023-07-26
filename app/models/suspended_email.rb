class SuspendedEmail < ApplicationRecord
  belongs_to :email_address, inverse_of: :suspended_emails
  validates :digested_base_email, presence: true

  def self.generate_email_digest(email)
    normalized_email = EmailNormalizer.new(email).normalized_email
    OpenSSL::Digest::SHA256.hexdigest(normalized_email)
  end

  def self.blocked_email_address(email)
    digested_base_email = generate_email_digest(email)
    find_by(digested_base_email: digested_base_email)&.email_address
  end
end
