# frozen_string_literal: true

class UpdatePasswordPresenter
  attr_reader :user, :required_password_change

  alias_method :required_password_change?, :required_password_change
  def initialize(user:, required_password_change: false)
    @user = user
    @required_password_change = required_password_change
  end

  def forbidden_passwords
    user.email_addresses.flat_map do |email_address|
      ForbiddenPasswords.new(email_address.email).call
    end.uniq
  end

  def aria_described_by_if_eligible
    return {} if required_password_change?
    {
      input_html: {
        aria: { describedby: 'password-strength password-description' },
      },
    }
  end

  def submit_text
    if required_password_change?
      I18n.t('forms.passwords.edit.buttons.submit')
    else
      I18n.t('forms.buttons.submit.update')
    end
  end
end
