class ImageUploadResponsePresenter
  include Rails.application.routes.url_helpers

  def initialize(form_response:, url_options: )
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
    if success?
      { success: true }
    elsif @form_response.errors.key?(:limit)
      { success: false, redirect: idv_session_errors_throttled_url }
    else
      hints = @form_response.errors[:hints]
      { success: false, errors: errors, hints: hints, remaining_attempts: remaining_attempts }
    end
  end

  def url_options
    @url_options
  end
end
