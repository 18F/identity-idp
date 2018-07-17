class TwoFactorLoginOptionsForm
  include ActiveModel::Model

  attr_reader :selection

  validates :selection, inclusion: { in: %w[voice sms auth_app piv_cac personal_key] }

  def initialize(user)
    self.user = user
  end

  def submit(params)
    self.selection = params[:selection]

    success = valid?

    FormResponse.new(success: success, errors: errors.messages, extra: extra_analytics_attributes)
  end

  private

  attr_accessor :user
  attr_writer :selection

  def extra_analytics_attributes
    {
      selection: selection,
    }
  end
end
