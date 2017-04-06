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
    length = RandomPhrase::WORD_LENGTH
    return false unless code =~ /^(?:[a-zA-Z0-9]{#{length}}([\s-])?){3}[a-zA-Z0-9]{#{length}}$/
    personal_key_generator = PersonalKeyGenerator.new(user)
    personal_key_generator.verify(code)
  end

  def extra_analytics_attributes
    {
      multi_factor_auth_method: 'personal key',
    }
  end
end
