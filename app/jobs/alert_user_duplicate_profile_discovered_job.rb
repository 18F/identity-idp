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
        next unless phone
        @telephony_response = Telephony.send_dupe_profile_created_notice(
          to: phone,
          country_code: Phonelib.parse(phone).country,
          agency_name: agency,
        )
      when SIGN_IN_ATTEMPTED
        mailer.dupe_profile_sign_in_attempted(agency_name: agency).deliver_now_or_later
        next unless phone
        @telephony_response = Telephony.send_dupe_profile_sign_in_attempted_notice(
          to: phone,
          country_code: Phonelib.parse(phone).country,
          agency_name: agency,
        )
      else
        analytics(user: user).one_account_dupe_profile_email_type_not_found(type: type)
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

  def phone
    @phone ||= MfaContext.new(@user).phone_configurations.take&.phone
  end
end
