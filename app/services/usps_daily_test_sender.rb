# Mails a letter to the designated receiver
class UspsDailyTestSender
  def run
    if valid_designated_receiver_pii?
      UspsConfirmationMaker.new(
        pii: designated_receiver_pii,
        issuer: nil, # TODO: login.gov internal issuer?
        profile: profile,
        otp: otp_from_date,
      ).perform
    else
      raise 'missing valid designated receiver pii'
    end
  rescue => err
    NewRelic::Agent.notice_error(err)
  end

  # @return [String] 10-digit OTP from the date
  # @example
  #   "JAN20_2020"
  def otp_from_date(date = Time.zone.today)
    date.strftime('%b%d_%Y').upcase
  end

  # @return [Hash]
  def designated_receiver_pii
    @designated_receiver_pii ||= JSON.parse(
      AppConfig.env.gpo_designated_receiver_pii,
      symbolize_names: true,
    )
  end

  def valid_designated_receiver_pii?
    %i[email first_name last_name address1 city state zipcode].all? do |key|
      designated_receiver_pii[key].present?
    end
  end

  def profile
    @profile ||= user.profiles.first || user.profiles.create
  end

  def user
    email = designated_receiver_pii[:email]
    @user ||= User.find_with_email(email) || User.create(email: email)
  end
end
