module UserEncryptedAttributeOverrides
  extend ActiveSupport::Concern

  class_methods do
    # override this Devise method to support our use of encrypted_email
    def find_first_by_auth_conditions(tainted_conditions, _opts = {})
      email = tainted_conditions[:email]
      return find_with_confirmed_email(email) if email.present?

      find_by(tainted_conditions)
    end

    def find_with_email(email)
      email_address = EmailAddress.find_with_confirmed_or_unconfirmed_email(email)
      email_address&.user
    end

    def find_with_confirmed_email(email)
      email_address = EmailAddress.confirmed.find_with_email(email)
      email_address&.user
    end
  end
end
