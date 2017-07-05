class CustomDeviseMailer < Devise::Mailer
  include Mailable
  include LocaleHelper
  before_action :attach_images
  layout 'layouts/user_mailer'
  default from: email_with_name(Figaro.env.email_from, Figaro.env.email_from)

  def reset_password_instructions(*)
    @locale = locale_url_param
    super
  end

  def confirmation_instructions(record, token, options = {})
    presenter = ConfirmationEmailPresenter.new(record, view_context)
    @first_sentence = presenter.first_sentence
    @confirmation_period = presenter.confirmation_period
    @request_id = options[:request_id]
    @locale = locale_url_param
    super
  end
end
