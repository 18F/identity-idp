# frozen_string_literal: true

class SelectEmailForm
  include ActiveModel::Model
  include ActionView::Helpers::TranslationHelper

  attr_reader :user, :selected_email

  validate :validate_owns_selected_email

  def initialize(user)
    @user = user
  end

  def submit(params)
    @selected_email = params[:selection]

    success = valid?
    process_successful_submission if success
    FormResponse.new(success:, errors:)
  end

  private

  def process_successful_submission
    EmailAddress.update_last_sign_in_at_on_user_id_and_email(
      user_id: @user.id,
      email: EmailAddress.find(@selected_email).email,
    )
  end

  def validate_owns_selected_email
    return if user.confirmed_email_addresses.exists?(id: selected_email)

    errors.add :email, I18n.t(
      'anonymous_mailer.password_reset_missing_user.subject',
    ), type: :selected_email
  end
end
