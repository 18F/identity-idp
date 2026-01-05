class SmsTextMailerPreview < ActionMailer::Preview
  def sms_message
    # Use existing data from the database or create mock data
    user = User.first || User.create!(name: 'Test User', phone_number: '555-1234')
    login_code = 'ABCD'

    SmsTextMailer.sms_message(user, login_code)
  end
end
