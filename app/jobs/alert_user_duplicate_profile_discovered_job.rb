# frozen_string_literal: true

class AlertUserDuplicateProfileDiscoveredJob < ApplicationJob
  ACCOUNT_VERIFIED = :account_verified
  SIGN_IN_ATTEMPTED = :sign_in

  DUPE_PROFILE_DETECTED = {
    sign_in: :sign_in,
    account_verified: :account_verified,
  }.freeze
  def perform(user:, agency:, type:)
    @user = user
    user.confirmed_email_addresses.each do |email_address|
      mailer = UserMailer.with(user: user, email_address: email_address)

      case type
      when ACCOUNT_VERIFIED
        mailer.dupe_profile_created(agency_name: agency).deliver_now_or_later
      when SIGN_IN_ATTEMPTED
        mailer.dupe_profile_sign_in_attempted(agency_name: agency).deliver_now_or_later
      end
    end
    return unless phone
    phone_params = {
      to: phone,
      country_code: Phonelib.parse(phone).country,
      agency_name: agency,
    }

    if type == SIGN_IN_ATTEMPTED
      Telephony.send_dupe_profile_sign_in_attempted_notice(
        phone_params,
      )
    elsif type == ACCOUNT_VERIFIED
      Telephony.send_dupe_profile_created_notice(
        phone_params,
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
