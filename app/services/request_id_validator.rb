class RequestIdValidator
  include ActiveModel::Model
  include ActionView::Helpers::TranslationHelper

  validate :validate_request_id

  def initialize(request_id)
    @request_id = request_id
  end

  def submit
    success = valid?

    FormResponse.new(
      success: success,
      errors: errors,
      extra: extra_attributes
    )
  end

  private

  attr_reader :request_id

  def validate_request_id
    return if request_id.blank?
    return if ServiceProviderRequest.where(uuid: request_id).exists?

    errors.add(:request_id, :invalid)
  end

  def extra_attributes
    {
      request_id: request_id,
    }
  end
end
