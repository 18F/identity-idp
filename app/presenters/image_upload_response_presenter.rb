class ImageUploadResponsePresenter
  include Rails.application.routes.url_helpers

  def initialize(form_response:, url_options:)
    @form_response = form_response
    @url_options = url_options
  end

  def success?
    @form_response.success?
  end

  def errors
    @form_response.errors.except(:hints).flat_map do |key, errs|
      Array(errs).map { |err| { field: key, message: err } }
    end
  end

  def remaining_attempts
    @form_response.to_h[:remaining_attempts]
  end

  def status
    if success?
      :ok
    elsif @form_response.errors.key?(:limit)
      :too_many_requests
    else
      :bad_request
    end
  end

  def as_json(*)
    if success? && !attention_with_barcode?
      { success: true }
    else
      hints = @form_response.errors[:hints]
      json = { success: false, errors: errors, remaining_attempts: remaining_attempts }
      json[:redirect] = idv_session_errors_throttled_url if remaining_attempts&.zero?
      json[:hints] = hints unless hints.blank?
      json[:ocr_pii] = ocr_pii
      json
    end
  end

  def url_options
    @url_options
  end

  private

  def attention_with_barcode?
    ocr_pii.present?
  end

  def ocr_pii
    @form_response.ocr_pii if @form_response.respond_to? :ocr_pii
  end
end
