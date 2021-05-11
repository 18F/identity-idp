class FormResponse
  def initialize(success:, errors: {}, extra: {})
    @success = success
    @errors = errors.is_a?(ActiveModel::Errors) ? errors.messages.to_hash : errors
    @extra = extra
    @extra.merge!(
      error_details: flatten_details(errors.details),
    ) if errors.is_a?(ActiveModel::Errors) && errors.details.present?
  end

  attr_reader :errors, :extra

  def success?
    @success
  end

  def to_h
    { success: success, errors: errors }.merge!(extra)
  end

  def merge(other)
    FormResponse.new(
      success: success? && other.success?,
      errors: errors.merge(other.errors, &method(:merge_arrays)),
      extra: extra.merge(other.extra) do |key, first, second|
        if key == :error_details
          first.merge(second, &method(:merge_arrays))
        else
          second
        end
      end,
    )
  end

  def first_error_message
    return if errors.blank?
    _key, message_or_messages = errors.first
    Array(message_or_messages).first
  end

  def ==(other)
    success? == other.success? &&
      errors == other.errors &&
      extra == other.extra
  end

  private

  def merge_arrays(_key, first, second)
    Array(first) + Array(second)
  end

  def flatten_details(details)
    details.to_hash.transform_values { |errors| errors.pluck(:error) }
  end

  attr_reader :success
end
