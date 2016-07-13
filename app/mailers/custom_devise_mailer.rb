class CustomDeviseMailer < Devise::Mailer
  before_action :attach_images
  layout 'layouts/user_mailer'

  def confirmation_instructions(record, token, options = {})
    user_decorator = UserDecorator.new(record)
    @first_sentence = user_decorator.first_sentence_for_confirmation_email
    @confirmation_period = user_decorator.confirmation_period
    super
  end

  def attach_images
    attachments.inline['logo.png'] = File.read('app/assets/images/logo.png')
  end
end
