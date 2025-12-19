# frozen_string_literal: true

class AlertUserDuplicateProfileDiscoveredJob < ApplicationJob
  def perform(user:, agency:, type:)
    @user = user
    user.confirmed_email_addresses.each do |email_address|
      mailer = UserMailer.with(user: user, email_address: email_address)

      case type
      when :account_verified
        mailer.dupe_profile_created(agency_name: agency).deliver_now_or_later
      when :sign_in
        mailer.dupe_profile_sign_in_attempted(agency_name: agency).deliver_now_or_later
      end
    end
    return unless phone
    if type == :sign_in
      Telephony.send_dupe_profile_sign_in_attempted_notice(
        to: phone,
        country_code: Phonelib.parse(phone).country,
      )
    elsif type == :account_verified
      Telephony.send_dupe_profile_created_notice(
        to: phone,
        country_code: Phonelib.parse(phone).country,
      )
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

  def phone
    @phone ||= MfaContext.new(@user).phone_configurations.take&.phone
  end
end
