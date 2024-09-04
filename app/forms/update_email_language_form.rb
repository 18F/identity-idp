# frozen_string_literal: true

class UpdateEmailLanguageForm
  include ActiveModel::Model

  attr_reader :user, :email_language

  validates_inclusion_of :email_language, in: I18n.available_locales.map(&:to_s)

  def initialize(user)
    @user = user
  end

  def submit(params)
    @email_language = params[:email_language]

    user.update!(email_language: email_language) if valid?

    FormResponse.new(
      success: valid?,
      errors:,
      serialize_error_details_only: false,
    )
  end
end
