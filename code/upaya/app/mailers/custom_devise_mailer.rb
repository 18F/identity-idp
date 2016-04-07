class CustomDeviseMailer < Devise::Mailer
  def confirmation_instructions(record, token, options = {})
    user_decorator = UserDecorator.new(record)
    @first_sentence = user_decorator.first_sentence_for_confirmation_email
    @confirmation_period = user_decorator.confirmation_period
    super
  end
end
