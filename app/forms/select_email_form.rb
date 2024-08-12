# frozen_string_literal: true

class SelectEmailForm
  include ActiveModel::Model
  include ActionView::Helpers::TranslationHelper

  attr_reader :user, :selected_email_id

  validate :validate_owns_selected_email

  def initialize(user)
    @user = user
  end

  def submit(params)
    @selected_email_id = params[:selected_email_id]

    success = valid?
    FormResponse.new(success:, errors:)
  end

  private

  def validate_owns_selected_email
    return if user.confirmed_email_addresses.exists?(id: selected_email_id)

    errors.add :email, I18n.t(
      'email_address.not_found',
    ), type: :selected_email_id
  end
end
