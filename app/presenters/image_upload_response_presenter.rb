# frozen_string_literal: true

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
    form_response_errors = @form_response.errors.deep_dup
    Idv::DocPiiForm.present_error(form_response_errors)
    form_response_errors.except(:hints).flat_map do |key, errs|
      Array(errs).map { |err| { field: key, message: err } }
    end
  end

  def remaining_submit_attempts
    @form_response.to_h[:remaining_submit_attempts]
  end

  def submit_attempts
    @form_response.to_h[:submit_attempts]
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
               remaining_submit_attempts: remaining_submit_attempts,
               submit_attempts: submit_attempts,
               doc_type_supported: doc_type_supported? }
      if remaining_submit_attempts&.zero?
        if @form_response.extra[:flow_path] == 'standard'
          json[:redirect] = idv_session_errors_rate_limited_url
        else # hybrid flow on mobile
          json[:redirect] = idv_hybrid_mobile_capture_complete_url
        end
      end
      json[:hints] = true if show_hints?
      json[:ocr_pii] = ocr_pii
      json[:result_failed] = doc_auth_failed?
      json[:result_code_invalid] = result_code_invalid?
      json[:doc_type_supported] = doc_type_supported?
      json[:selfie_status] = selfie_status if show_selfie_failures?
      json[:selfie_live] = selfie_live? if show_selfie_failures?
      json[:selfie_quality_good] = selfie_quality_good? if show_selfie_failures?
      json[:failed_image_fingerprints] = failed_fingerprints
      json
    end
  end

  def url_options
    @url_options
  end

  private

  def result_code_invalid?
    @form_response.to_h[:doc_auth_result] != DocAuth::LexisNexis::ResultCodes::PASSED.name &&
      !attention_with_barcode?
  end

  def doc_auth_failed?
    @form_response.to_h[:transaction_status] == DocAuth::LexisNexis::TransactionCodes::FAILED.name
  end

  def show_hints?
    @form_response.errors[:hints].present? || attention_with_barcode?
  end

  def attention_with_barcode?
    @form_response.respond_to?(:attention_with_barcode?) && @form_response.attention_with_barcode?
  end

  def ocr_pii
    return unless success?
    return unless attention_with_barcode? && @form_response.respond_to?(:pii_from_doc)
    @form_response.pii_from_doc.to_h.slice(:first_name, :last_name, :dob)
  end

  def doc_type_supported?
    # default to true by assuming using supported doc type unless we clearly detect unsupported type
    @form_response.respond_to?(:id_type_supported?) ? @form_response.id_type_supported? : true
  end

  def failed_fingerprints
    @form_response.extra[:failed_image_fingerprints] || { front: [], back: [], selfie: [] }
  end

  def show_selfie_failures?
    @form_response.extra[:liveness_checking_required] == true
  end

  def selfie_status
    @form_response.respond_to?(:selfie_status) ? @form_response.selfie_status : :not_processed
  end

  def selfie_live?
    @form_response.respond_to?(:selfie_live?) ? @form_response.selfie_live? : true
  end

  def selfie_quality_good?
    @form_response.respond_to?(:selfie_quality_good?) ? @form_response.selfie_quality_good? : true
  end
end
