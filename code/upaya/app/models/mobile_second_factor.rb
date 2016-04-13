class MobileSecondFactor
  def self.transmit(user)
    SmsSenderOtpJob.perform_later(user)
  end
end
