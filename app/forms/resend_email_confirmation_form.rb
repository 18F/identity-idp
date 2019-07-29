class ResendEmailConfirmationForm
  include ActiveModel::Model

  attr_reader :email, :request_id

  def self.model_name
    ActiveModel::Name.new(self, nil, 'User')
  end

  def initialize(params = {})
    @email = params[:email]
    @request_id = params[:request_id]
  end

  def resend
    'true'
  end
end
