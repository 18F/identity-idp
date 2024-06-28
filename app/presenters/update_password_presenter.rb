# frozen_string_literal: true

class UpdatePasswordPresenter
  attr_reader :user, :required_password_change
  def initialize(user:, required_password_change: false)
    @user = user
    @required_password_change = required_password_change
  end

  def forbidden_passwords
    user.email_addresses.flat_map do |email_address|
      ForbiddenPasswords.new(email_address.email).call
    end.uniq
  end

  def submit_text
    if required_password_change
      t('forms.passwords.edit.buttons.submit')
    else
      t('forms.buttons.submit.update')
    end
  end
end
