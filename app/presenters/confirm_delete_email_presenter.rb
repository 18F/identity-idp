class ConfirmDeleteEmailPresenter
  include ActionView::Helpers::TranslationHelper

  attr_reader :current_user, :email_address

  def initialize(current_user, email_address)
    @current_user = current_user
    @email_address = email_address
  end

  def confirm_delete_message
    t('email_addresses.delete.confirm', email: @email_address.email)
  end
end
