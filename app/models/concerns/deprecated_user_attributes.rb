module DeprecatedUserAttributes
  extend ActiveSupport::Concern

  DEPRECATED_ATTRIBUTES = %i[
    email confirmed_at
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
    IdentityConfig.store.show_user_attribute_deprecation_warnings
  end
end
