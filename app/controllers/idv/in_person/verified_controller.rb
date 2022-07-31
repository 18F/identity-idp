module Idv
  module InPerson
    class VerifiedController < ApplicationController
      def show
        @presenter = ReadyToVerifyPresenter.new(enrollment: enrollment)
      end

      def send_verified_email(user, enrollment)
        user.confirmed_email_addresses.each do |email_address|
          UserMailer.in_person_verified(
            user,
            email_address,
            first_name: user_session.dig(:idv, :pii, :first_name),
            enrollment: enrollment,
          ).deliver_now_or_later
        end
      end
    end
  end
end
