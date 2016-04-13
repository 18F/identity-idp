UserProfileUpdater = Struct.new(:user, :flash) do
  def send_notifications
    updatable_attributes.each do |attr|
      send(:"notify_about_existing_#{attr}") if send(:"#{attr}_already_taken?")
    end
  end

  def attribute_already_taken_and_no_other_errors?
    attribute_already_taken? && no_other_errors?
  end

  def set_flash_message
    unless needs_to_confirm_profile_changes?
      return flash[:notice] = I18n.t('devise.registrations.updated')
    end

    if attributes_to_confirm.size == 1
      attr = attributes_to_confirm.pop
      flash[:notice] = I18n.t("devise.registrations.#{attr}_update_needs_confirmation")
    else
      flash[:notice] = I18n.t('devise.registrations.email_and_mobile_need_confirmation')
    end
  end

  def mobile_already_taken?
    user.errors.include?(:mobile) && user.errors[:mobile] == [I18n.t('errors.messages.taken')]
  end

  def attribute_already_taken?
    user.errors.values.flatten.include?(I18n.t('errors.messages.taken'))
  end

  def needs_to_confirm_mobile_change?
    user.pending_mobile_reconfirmation? || user.mobile_changed?
  end

  def delete_already_taken_errors
    updatable_attributes.each do |attr|
      user.errors.delete(attr.to_sym) if send(:"#{attr}_already_taken?")
    end
  end

  def send_confirmation_email_if_needed
    return if email_already_taken?

    return unless !user.pending_reconfirmation? && user.email_changed?

    postpone_email_change_until_confirmation_and_regenerate_confirmation_token
    send_confirmation_instructions
  end

  private

  def updatable_attributes
    @updatable_attributes ||= %w(mobile email)
  end

  def notify_about_existing_email
    recipient = User.find_by_email(user.email)
    UserMailer.signup_with_your_email(recipient).deliver_later
  end

  def notify_about_existing_mobile
    recipient = User.find_by_mobile(user.mobile)
    SmsSenderExistingMobileJob.perform_later(recipient)
  end

  def email_already_taken?
    user.errors.include?(:email) && user.errors[:email].uniq == [I18n.t('errors.messages.taken')]
  end

  def no_other_errors?
    user.errors.values.flatten.uniq == [I18n.t('errors.messages.taken')]
  end

  def needs_to_confirm_profile_changes?
    attributes_to_confirm.any?
  end

  def attributes_to_confirm
    @attributes_to_confirm ||= updatable_attributes.select do |attr|
      send(:"needs_to_confirm_#{attr}_change?")
    end
  end

  def needs_to_confirm_email_change?
    user.pending_reconfirmation? || user.email_changed?
  end

  # The methods below are modified versions of Devise's Confirmable module.
  # These methods are necessary in the scenario where a user needs to confirm
  # their new email, but they also have a "mobile already taken" error, which
  # prevents the Devise code from running because the user is not valid.
  # Therefore, we need to update the user attributes directly and bypass
  # validations and callbacks.
  def postpone_email_change_until_confirmation_and_regenerate_confirmation_token
    user.update_columns(unconfirmed_email: user.changes['email'][1])

    generate_confirmation_token
  end

  def generate_confirmation_token
    raw, = Devise.token_generator.generate(User, :confirmation_token)
    user.update_columns(confirmation_token: raw)
    user.update_columns(confirmation_sent_at: Time.now.utc)
  end

  def send_confirmation_instructions
    opts = { to: user.unconfirmed_email }
    user.send_devise_notification(:confirmation_instructions, user.confirmation_token, opts)
  end
end
