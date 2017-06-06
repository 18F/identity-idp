module PersonalKeyValidator
  extend ActiveSupport::Concern

  private

  def normalize_personal_key(personal_key = nil)
    return nil if personal_key.blank?
    personal_key_generator.normalize(personal_key)
  end

  def check_personal_key
    return if personal_key_format_matches? && personal_key_generator.verify(personal_key)
    errors.add :personal_key, :personal_key_incorrect
  end

  def personal_key_format_matches?
    personal_key =~ PersonalKeyFormatter.regexp
  end

  def personal_key_generator
    @_personal_key_generator ||= PersonalKeyGenerator.new(user)
  end
end
