UserFlashUpdater = Struct.new(:user, :flash) do
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

  def needs_to_confirm_mobile_change?
    user.pending_mobile_reconfirmation? || user.mobile_changed?
  end

  private

  def needs_to_confirm_profile_changes?
    attributes_to_confirm.any?
  end

  def attributes_to_confirm
    @attributes_to_confirm ||= updatable_attributes.select do |attr|
      send(:"needs_to_confirm_#{attr}_change?")
    end
  end

  def updatable_attributes
    @updatable_attributes ||= %w(mobile email)
  end

  def needs_to_confirm_email_change?
    user.pending_reconfirmation? || user.email_changed?
  end
end
