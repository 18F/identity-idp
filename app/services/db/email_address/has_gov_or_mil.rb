module Db
  module EmailAddress
    class HasGovOrMil
      def self.call(user)
        user.email_addresses.any? { |email_address| piv_cac_email?(email_address.email) }
      end

      def self.piv_cac_email?(email)
        ['.gov', '.mil'].include?(email[-4..-1])
      end
      private_class_method :piv_cac_email?
    end
  end
end
