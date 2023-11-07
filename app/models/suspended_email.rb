class SuspendedEmail < ApplicationRecord
  belongs_to :email_address
  validates :digested_base_email, presence: true

  class << self
    def generate_email_digest(email)
      normalized_email = EmailNormalizer.new(email).normalized_email
      OpenSSL::Digest::SHA256.hexdigest(normalized_email)
    end

    def create_from_email_address!(email_address)
      create!(
        digested_base_email: generate_email_digest(email_address.email),
        email_address:,
      )
    end

    # @return [SuspendedEmail,nil]
    def find_with_email(email)
      find_by(digested_base_email: generate_email_digest(email))
    end

    # @return [SuspendedEmail,nil]
    def find_with_email_digest(digest)
      find_by(digested_base_email: digest)
    end
  end
end
