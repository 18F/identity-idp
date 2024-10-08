# frozen_string_literal: true

class SelectEmailForm
  include ActiveModel::Model
  include ActionView::Helpers::TranslationHelper

  attr_reader :user, :identity, :selected_email_id

  validate :validate_owns_selected_email

  def initialize(user:, identity: nil)
    @user = user
    @identity = identity
  end

  def submit(params)
    @selected_email_id = params[:selected_email_id]

    success = valid?
    identity.update(email_address_id: selected_email_id) if success && identity

    FormResponse.new(success:, errors:, serialize_error_details_only: true)
  end

  private

  def validate_owns_selected_email
    return if user.confirmed_email_addresses.exists?(id: selected_email_id)
    errors.add(:selected_email_id, :not_found, message: t('email_address.not_found'))
  end
end
