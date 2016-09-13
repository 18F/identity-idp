class ContactController < ApplicationController
  def new
    @contact_form = ContactForm.new
  end

  def create
    @contact_form = ContactForm.new

    if @contact_form.submit(form_params)
      UserMailer.contact_request(form_params).deliver_later
      flash[:success] = t('contact.messages.thanks')
      redirect_to contact_url
    else
      render :new
    end
  end

  private

  def form_params
    params.require(:contact_form).permit(:want_learn, :want_tell, :email_or_tel, :comments)
  end
end
