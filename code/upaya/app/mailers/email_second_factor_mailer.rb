class EmailSecondFactorMailer < ActionMailer::Base
  default from: 'upaya@18f.gov'

  def your_code_is(user)
    @code = user.otp_code
    mail(
      to: user.email,
      subject: 'Secure one-time password notification'
    )
  end
end
