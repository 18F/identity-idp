EmailNotifier = Struct.new(:user) do
  def send_password_changed_email
    UserMailer.password_changed(user).deliver_later
  end

  def send_email_changed_email
    UserMailer.email_changed(old_email).deliver_later if email_changed?
  end

  private

  def email_changed?
    changed_attributes.fetch('email', false)
  end

  def changed_attributes
    @changed_attributes ||= user.previous_changes
  end

  def old_email
    changed_attributes['email'].first
  end
end
