class ImageUploadResponsePresenter
  def initialize(form:, form_response:)
    @form = form
    @form_response = form_response
  end

  def success
    @form_response.success?
  end

  def errors
    @form_response.errors.flat_map do |key, errs|
      Array(errs).map { |err| { field: key, message: err } }
    end
  end

  def remaining_attempts
    @form.remaining_attempts
  end

  def as_json(*)
    {
      success: success,
      errors: errors,
      remaining_attempts: remaining_attempts,
    }
  end
end
