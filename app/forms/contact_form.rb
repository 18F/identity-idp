class ContactForm
  include ActiveModel::Model

  validates :email_or_tel, presence: true

  attr_accessor :want_learn, :want_tell, :email_or_tel, :comments

  def submit(params)
    self.email_or_tel = params[:email_or_tel]
    valid?
  end
end
