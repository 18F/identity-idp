# frozen_string_literal: true

class SelectEmailForm
  include ActiveModel::Model
  include ActionView::Helpers::TranslationHelper

  attr_reader :user, :selected_email

  validate :owns_selected_email

  def initialize(user)
    @user = user
  end

  def owns_selected_email
    user_selected_email = EmailAddress.find_with_email(selected_email)
    return if @user.id == user_selected_email&.user&.id

    errors.add :email, I18n.t(
      'anonymous_mailer.password_reset_missing_user.subject',
    ), type: :selected_email
  end

  def submit(params)
    @selected_email = params[:selection]

    if valid?
      process_successful_submission
    else
      self.success = false
    end

    FormResponse.new(success: success, errors: errors)
  end

  private

  attr_accessor :success

  def process_successful_submission
    self.success = true
    EmailAddress.update_last_sign_in_at_on_user_id_and_email(
      user_id: @user.id,
      email: @selected_email,
    )
  end
end
