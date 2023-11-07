class UpdateEmailLanguageForm
  include ActiveModel::Model

  attr_reader :user, :email_language

  validates_inclusion_of :email_language, in: I18n.available_locales.map(&:to_s)

  def initialize(user)
    @user = user
  end

  def submit(params)
    @email_language = params[:email_language]

    UpdateUser.new(user:, attributes: { email_language: }).call if valid?

    FormResponse.new(
      success: valid?,
      errors:,
    )
  end
end
