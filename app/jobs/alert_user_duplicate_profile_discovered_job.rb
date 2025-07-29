# frozen_string_literal: true

class AlertUserDuplicateProfileDiscoveredJob < ApplicationJob
  ACCOUNT_CREATED = :account_created
  SIGN_IN_ATTEMPTED = :sign_in_attempted
  def perform(user:, agency:, type:)
    user.confirmed_email_addresses.each do |email_address|
      mailer = UserMailer.with(user: user, email_address: email_address)

      case type
      when ACCOUNT_CREATED
        mailer.dupe_profile_created(agency_name: agency).deliver_now_or_later
      when SIGN_IN_ATTEMPTED
        mailer.dupe_profile_sign_in_attempted(agency_name: agency).deliver_now_or_later
      else
        analytics(user: user).duplicate_profile_email_type_not_found(type: type)
      end
    end
  end

  private

  def analytics(user:)
    @analytics ||= Analytics.new(
      user: user,
      request: nil,
      sp: nil,
      session: {},
    )
  end
end
