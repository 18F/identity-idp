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
    form_response_errors = @form_response.errors
    if form_response_errors.values_at(:name, :dob_error, :dob_min_age_error, :state).compact.many?
      form_response_errors = { pii: I18n.t('doc_auth.errors.general.no_liveness') }
    end
    form_response_errors.except(:hints).flat_map do |key, errs|
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
      json = { success: false,
               errors: errors,
               remaining_attempts: remaining_attempts,
               doc_type_supported: doc_type_supported? }
      if remaining_attempts&.zero?
        if @form_response.extra[:flow_path] == 'standard'
          json[:redirect] = idv_session_errors_rate_limited_url
        else # hybrid flow on mobile
          json[:redirect] = idv_hybrid_mobile_capture_complete_url
        end
      end
      json[:hints] = true if show_hints?
      json[:ocr_pii] = ocr_pii
      json[:result_failed] = doc_auth_result_failed?
      json[:doc_type_supported] = doc_type_supported?
      json[:failed_image_fingerprints] = failed_fingerprints
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

  def doc_type_supported?
    # default to true by assuming using supported doc type unless we clearly detect unsupported type
    @form_response.respond_to?(:id_type_supported?) ? @form_response.id_type_supported? : true
  end

  def failed_fingerprints
    @form_response.extra[:failed_image_fingerprints] || { front: [], back: [] }
  end
end
