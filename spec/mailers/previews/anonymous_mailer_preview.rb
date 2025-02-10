class AnonymousMailerPreview < ActionMailer::Preview
  def password_reset_missing_user
    AnonymousMailer.with(email:).password_reset_missing_user(request_id:)
  end

  private

  def email
    'email@example.com'
  end

  def request_id
    SecureRandom.uuid
  end
end
