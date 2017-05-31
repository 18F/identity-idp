module PersonalKeyValidator
  extend ActiveSupport::Concern

  included do
    validate :valid_personal_key?
  end

  private

  def normalize_personal_key(personal_key = nil)
    return nil if personal_key.blank?
    personal_key_generator.normalize(personal_key)
  end

  def valid_personal_key?
    return false unless personal_key =~ /\A#{PersonalKeyFormatter.new.regexp}\Z/
    personal_key_generator.verify(personal_key)
  end

  def personal_key_generator
    @_personal_key_generator ||= PersonalKeyGenerator.new(user)
  end
end
