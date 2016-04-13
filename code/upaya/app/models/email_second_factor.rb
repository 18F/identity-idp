class EmailSecondFactor
  def self.transmit(user)
    EmailSecondFactorMailer.your_code_is(user).deliver_later
  end
end
