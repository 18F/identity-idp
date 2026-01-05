# frozen_string_literal: true

class SmsTextMailer < ActionMailer::Base
  include LocaleHelper

  layout 'sms_message'
  def sms_message(user, login_code)
    @user = user
    @login_code = login_code
    @url = 'example.com'

    mail(to: '3015555555', subject: 'SMS Preview') do |format|
      format.text # Use only the text template for SMS
    end
  end
end
