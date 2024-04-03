# frozen_string_literal: true

class ResendEmailConfirmationForm
  include ActiveModel::Model

  attr_reader :email

  def self.model_name
    ActiveModel::Name.new(self, nil, 'User')
  end

  def initialize(params = {})
    @email = params[:email]
  end

  def resend
    'true'
  end
end
