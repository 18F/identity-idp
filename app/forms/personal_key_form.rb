class PersonalKeyForm
  include ActiveModel::Model

  attr_accessor :code

  def initialize(user, code = [])
    @user = user
    @code = code
  end

  def submit
    @success = valid_personal_key?

    UpdateUser.new(user: user, attributes: { personal_key: nil }).call if success

    FormResponse.new(success: success, errors: errors.messages, extra: extra_analytics_attributes)
  end

  private

  attr_reader :user, :success

  def valid_personal_key?
    word_regexp = /\w{#{RandomPhrase::WORD_LENGTH}}/
    return false unless code =~ /\A#{word_regexp} #{word_regexp} #{word_regexp} #{word_regexp}\Z/
    personal_key_generator = PersonalKeyGenerator.new(user)
    personal_key_generator.verify(code)
  end

  def extra_analytics_attributes
    {
      multi_factor_auth_method: 'personal key',
    }
  end
end
