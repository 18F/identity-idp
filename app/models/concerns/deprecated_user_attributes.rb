module DeprecatedUserAttributes
  extend ActiveSupport::Concern

  DEPRECATED_ATTRIBUTES = %i[
    email_fingerprint encrypted_email email confirmed_at confirmation_token confirmation_sent_at
  ].freeze

  def []=(attribute, value)
    if show_user_attribute_deprecation_warnings && DEPRECATED_ATTRIBUTES.include?(attribute)
      warning = "Setting #{attribute} on User is deprecated. Use EmailAddress instead."
      warn warning
    end
    super
  end

  def [](attribute)
    if show_user_attribute_deprecation_warnings && DEPRECATED_ATTRIBUTES.include?(attribute)
      warning = "Reading #{attribute} on User is deprecated. Use EmailAddress instead."
      warn warning
    end
    super
  end

  private

  def show_user_attribute_deprecation_warnings
    Figaro.env.show_user_attribute_deprecation_warnings == 'true'
  end
end
