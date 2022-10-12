class EditPhoneForm
  include ActiveModel::Model

  validates :delivery_preference, inclusion: { in: %w[voice sms] }

  attr_reader :user, :phone_configuration, :delivery_preference, :make_default_number

  delegate :masked_phone, to: :phone_configuration

  def initialize(user, phone_configuration)
    @user = user
    @phone_configuration = phone_configuration
    @delivery_preference = phone_configuration.delivery_preference
    @make_default_number = default_phone_configuration?
  end

  def submit(params)
    ingest_submitted_params(params)
    success = valid?
    update_phone_configuration if success
    FormResponse.new(success: success, errors: errors, extra: extra_analytics_attributes)
  end

  def delivery_preference_sms?
    phone_configuration&.delivery_preference == 'sms'
  end

  def delivery_preference_voice?
    phone_configuration&.delivery_preference == 'voice'
  end

  def default_phone_configuration?
    phone_configuration == user.default_phone_configuration
  end

  def one_phone_configured?
    user.phone_configurations.count == 1
  end

  private

  attr_writer :delivery_preference, :make_default_number

  def extra_analytics_attributes
    {
      delivery_preference: delivery_preference,
      make_default_number: make_default_number,
      phone_configuration_id: phone_configuration.id,
    }
  end

  def ingest_submitted_params(params)
    delivery_preference_submission = params[:delivery_preference]
    make_default_number_submission = params[:make_default_number]

    self.delivery_preference = delivery_preference_submission if delivery_preference_submission
    self.make_default_number = make_default_number_submission if make_default_number_submission
  end

  def update_phone_configuration
    update_params = { delivery_preference: delivery_preference }
    update_params[:made_default_at] = Time.zone.now if make_default_number
    phone_configuration.update!(update_params)
  end
end
