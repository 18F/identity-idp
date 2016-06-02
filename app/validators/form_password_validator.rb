module FormPasswordValidator
  extend ActiveSupport::Concern

  included do
    validates :password,
              presence: true,
              length: Devise.password_length,
              confirmation: true,
              if: :password_required?
  end

  private

  def password_required?
    new_user? || user_resetting_password? || user_updating_password?
  end

  def new_user?
    @user.encrypted_password.blank?
  end

  def user_resetting_password?
    @user.reset_password_token.present?
  end

  def user_updating_password?
    password.present? || password_confirmation.present?
  end
end
