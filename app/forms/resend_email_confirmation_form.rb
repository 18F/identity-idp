# frozen_string_literal: true

class ResendEmailConfirmationForm
  include ActiveModel::Model

  attr_reader :email, :terms_accepted

  def self.model_name
    ActiveModel::Name.new(self, nil, 'User')
  end

  def initialize(params = {})
    @email = params[:email]
    @terms_accepted = params[:terms_accepted]
  end

  def resend
    'true'
  end
end
