class CustomDeviseMailer < Devise::Mailer
  include Mailable
  before_action :attach_images
  layout 'layouts/user_mailer'
  default from: email_with_name(Figaro.env.email_from, Figaro.env.email_from)

  def confirmation_instructions(record, token, options = {})
    user_decorator = record.decorate
    @first_sentence = user_decorator.first_sentence_for_confirmation_email
    @confirmation_period = user_decorator.confirmation_period
    super
  end
end
