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
      json = { success: false, errors: errors, remaining_attempts: remaining_attempts }
      json[:redirect] = idv_session_errors_throttled_url if remaining_attempts&.zero?
      json[:hints] = true if show_hints?
      json[:ocr_pii] = ocr_pii
      json[:result_failed] = doc_auth_result_failed?
      json
    end
  end

  def url_options
    @url_options
  end

  private

  def doc_auth_result_failed?
    @form_response.to_h[:doc_auth_result] == DocAuth::Acuant::ResultCodes::FAILED.name
  end

  def show_hints?
    @form_response.errors[:hints].present? || attention_with_barcode?
  end

  def attention_with_barcode?
    @form_response.respond_to?(:attention_with_barcode?) && @form_response.attention_with_barcode?
  end

  def ocr_pii
    return unless attention_with_barcode? && @form_response.respond_to?(:pii_from_doc)
    @form_response.pii_from_doc&.slice(:first_name, :last_name, :dob)
  end
end
