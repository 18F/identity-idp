module FormPasswordValidator
  extend ActiveSupport::Concern

  included do
    attr_accessor :password, :password_confirmation, :validate_confirmation
    attr_reader :user

    validates :password,
              presence: true,
              length: { in: Devise.password_length }
    validates :password_confirmation,
              presence: true,
              length: { in: Devise.password_length },
              if: -> { validate_confirmation }

    validate :password_graphemes_length, :not_pwned, :passwords_match
  end

  private

  def password_graphemes_length
    return if errors.messages.present?
    if password.grapheme_clusters.length < Devise.password_length.min
      errors.add(
        :password,
        :too_short,
        count: Devise.password_length.min,
        type: :too_short,
      )
    elsif password.grapheme_clusters.length > Devise.password_length.max
      errors.add(:password, :too_long, count: Devise.password_length.max, type: :too_long)
    end
  end

  def not_pwned
    return if password.blank? || !PwnedPasswords::LookupPassword.call(password)

    errors.add :password, :pwned_password, type: :pwned_password
  end

  def passwords_match
    return unless validate_confirmation

    if password != password_confirmation
      errors.add(
        :password_confirmation, I18n.t('errors.messages.password_mismatch'),
        type: :mismatch
      )
    end
  end
end
