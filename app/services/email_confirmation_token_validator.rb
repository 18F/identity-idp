class EmailConfirmationTokenValidator
  include ActiveModel::Model

  attr_reader :email_address

  validate :token_found
  validate :email_not_already_confirmed, if: :email_address_found_with_token?
  validate :token_not_expired, if: :email_address_found_with_token?

  def initialize(email_address, current_user = nil)
    @current_user = current_user
    @email_address = email_address
    @user = email_address&.user
  end

  def submit
    @success = valid? && @email_address.present?

    FormResponse.new(success: success, errors: errors, extra: extra_analytics_attributes)
  end

  def email_address_already_confirmed?
    already_confirmed_email_address.present?
  end

  def email_address_already_confirmed_by_user?(user)
    already_confirmed_email_address.user_id == user.id
  end

  def confirmation_period_expired?
    return false unless email_address_found_with_token?
    confirmation_sent_at = @email_address.confirmation_sent_at
    return true if confirmation_sent_at.blank?
    expiration_time = confirmation_sent_at + email_valid_for_duration
    Time.zone.now > expiration_time
  end

  private

  attr_accessor :user, :current_user
  attr_reader :success

  def extra_analytics_attributes
    {
      user_id: user&.uuid,
    }
  end

  def confirmation_token; end

  def email_not_already_confirmed
    return if already_confirmed_email_address.nil?
    errors.add(:confirmation_token, :already_confirmed, type: :already_confirmed)
  end

  def already_confirmed_email_address
    return unless email_address_found_with_token?
    @already_confirmed_email_address ||= EmailAddress.where(
      'email_fingerprint=? AND confirmed_at IS NOT NULL',
      Pii::Fingerprinter.fingerprint(email_address.email),
    ).first
  end

  def token_found
    unless email_address_found_with_token?
      errors.add(
        :confirmation_token,
        :not_found,
        type: :not_found,
      )
    end
  end

  def email_address_found_with_token?
    return if current_user.present? && user != current_user
    email_address.present?
  end

  def token_not_expired
    if confirmation_period_expired?
      errors.add(
        :confirmation_token,
        :expired,
        type: :expired,
      )
    end
  end

  def email_valid_for_duration
    IdentityConfig.store.add_email_link_valid_for_hours.hours
  end
end
