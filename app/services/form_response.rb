class FormResponse
  def initialize(success:, errors:, extra: {})
    @success = success
    @errors = errors
    @extra = extra
  end

  attr_reader :errors

  def success?
    @success
  end

  def to_h
    { success: @success, errors: @errors }.merge!(@extra)
  end
end
