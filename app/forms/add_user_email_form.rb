class AddUserEmailForm
  include ActiveModel::Model
  include FormAddEmailValidator
  include ActionView::Helpers::TranslationHelper

  attr_reader :email

  def self.model_name
    ActiveModel::Name.new(self, nil, 'User')
  end

  def user
    @user ||= User.new
  end

  def submit(user, params)
    @user = user
    @email = params[:email]
    @email_address = email_address_record(@email)

    if valid?
      process_successful_submission
    else
      @success = false
    end

    FormResponse.new(success: success, errors: errors, extra: extra_analytics_attributes)
  end

  def email_address_record(email)
    record = EmailAddress.where(user_id: user.id).find_with_email(email) ||
             EmailAddress.new(user_id: user.id, email: email)

    record.confirmation_token = SecureRandom.uuid
    record.confirmation_sent_at = Time.zone.now

    record
  end

  private

  attr_writer :email
  attr_reader :success, :email_address

  def process_successful_submission
    @success = true
    email_address.save!
    SendAddEmailConfirmation.new(user).call(email_address)
  end

  def extra_analytics_attributes
    {
      user_id: existing_user.uuid,
      domain_name: email&.split('@')&.last,
    }
  end

  def existing_user
    @existing_user ||= User.find_with_email(email) || AnonymousUser.new
  end
end
