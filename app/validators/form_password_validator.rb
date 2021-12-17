module FormPasswordValidator
  extend ActiveSupport::Concern

  included do
    attr_accessor :password
    attr_reader :user

    validates :password,
              presence: true,
              length: { in: Devise.password_length }
    validate :password_graphemes_length
    validate :strong_password
    validate :not_pwned
  end

  private

  ZXCVBN_TESTER = ::Zxcvbn::Tester.new

  def strong_password
    return unless errors.messages.blank? && password_score.score < min_password_score

    errors.add :password, :weak_password, **i18n_variables, type: :weak_password
  end

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

  def password_score
    @password_score = ZXCVBN_TESTER.test(
      password,
      user.email_addresses.flat_map { |address| ForbiddenPasswords.new(address.email).call },
    )
  end

  def not_pwned
    return if password.blank? || !PwnedPasswords::LookupPassword.call(password)

    errors.add :password, :pwned_password, type: :pwned_password
  end

  def min_password_score
    IdentityConfig.store.min_password_score
  end

  def i18n_variables
    {
      feedback: zxcvbn_feedback,
    }
  end

  def zxcvbn_feedback
    feedback = @password_score.feedback.values.flatten.reject(&:empty?)

    feedback.map do |error|
      I18n.t("zxcvbn.feedback.#{i18n_key(error)}")
    end.join('. ').gsub(/\.\s*\./, '.')
  end

  def i18n_key(key)
    key.tr(' -', '_').gsub(/\W/, '').downcase
  end
end
