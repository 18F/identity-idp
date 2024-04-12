# frozen_string_literal: true

module DataRequests
  module Deployed
    class CreateEmailAddressesReport
      attr_reader :user

      def initialize(user)
        @user = user
      end

      def call
        user.email_addresses.map do |email_address|
          {
            email: email_address.email,
            created_at: email_address.created_at,
            confirmed_at: email_address.confirmed_at,
          }
        end
      end
    end
  end
end
