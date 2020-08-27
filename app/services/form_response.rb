class FormResponse
  def initialize(success:, errors:, extra: {})
    @success = success
    @errors = errors.to_hash
    @extra = extra
  end

  attr_reader :errors, :extra

  def success?
    @success
  end

  def to_h
    { success: success, errors: errors }.merge!(extra)
  end

  def merge(other)
    errors = @errors.presence || other.errors
    errors = { other: other.errors } if other.errors.is_a?(Array)
    FormResponse.new(
      success: success? && other.success?,
      errors: errors,
      extra: extra.merge(other.extra),
    )
  end

  private

  attr_reader :success
end
