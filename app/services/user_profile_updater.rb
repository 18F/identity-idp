UserProfileUpdater = Struct.new(:user) do
  def send_notifications
    updatable_attributes.each do |attr|
      if decorator.send(:"#{attr}_already_taken?")
        send(:"notify_about_existing_#{attr}")
      end
    end
  end

  def attribute_already_taken_and_no_other_errors?
    attribute_already_taken? && no_other_errors?
  end

  def attribute_already_taken?
    user.errors.values.flatten.include?(I18n.t('errors.messages.taken'))
  end

  def delete_already_taken_errors
    updatable_attributes.each do |attr|
      user.errors.delete(attr.to_sym) if decorator.send(:"#{attr}_already_taken?")
    end
  end

  private

  def updatable_attributes
    @updatable_attributes ||= %w(mobile email)
  end

  def notify_about_existing_email
    UserMailer.signup_with_your_email(user.email).deliver_later
  end

  def notify_about_existing_mobile
    SmsSenderExistingMobileJob.perform_later(user.mobile)
  end

  def no_other_errors?
    user.errors.values.flatten.uniq == [I18n.t('errors.messages.taken')]
  end

  def decorator
    @decorator ||= UserDecorator.new(user)
  end
end
