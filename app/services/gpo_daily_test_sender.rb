# Mails a letter to the designated receiver
class GpoDailyTestSender
  def run
    if valid_designated_receiver_pii?
      GpoConfirmationMaker.new(
        pii: IdentityConfig.store.gpo_designated_receiver_pii,
        issuer: nil,
        profile_id: -1, # profile_id can't be null on GpoConfirmationCode
        otp: otp_from_date,
      ).perform
    else
      Rails.logger.warn(
        {
          source: 'GpoDailyTestSender',
          message: 'missing valid designated receiver pii, not enqueueing a test sender',
        }.to_json,
      )
    end
  end

  # @return [String] 10-digit OTP from the date
  # @example
  #   "JAN20_2020"
  def otp_from_date(date = Time.zone.today)
    date.strftime('%b%d_%Y').upcase
  end

  def valid_designated_receiver_pii?
    %i[first_name last_name address1 city state zipcode].all? do |key|
      IdentityConfig.store.gpo_designated_receiver_pii[key].present?
    end
  end
end
