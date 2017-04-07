class PersonalKeyForm
  include ActiveModel::Model

  attr_accessor :code

  def initialize(user, code = nil)
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
    char_count = RandomPhrase::WORD_LENGTH
    word_count = Figaro.env.recovery_code_length.to_i
    valid_char = '[a-zA-Z0-9]'
    return false unless code =~
      /\A(?:#{valid_char}{#{char_count}}([\s-])?){#{word_count - 1}}#{valid_char}{#{char_count}}\Z/
    personal_key_generator = PersonalKeyGenerator.new(user)
    personal_key_generator.verify(code)
  end

  def extra_analytics_attributes
    {
      multi_factor_auth_method: 'personal key',
    }
  end
end
