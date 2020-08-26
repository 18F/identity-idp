class FormResponse
  def initialize(success:, errors:, extra: {})
    @success = success
    @errors = errors.to_hash
    @extra = extra
  end

  attr_reader :errors
  attr_accessor :extra # so we can chain extra analytics

  def success?
    @success
  end

  def to_h
    { success: success, errors: errors }.merge!(extra)
  end

  private

  attr_reader :success
end
