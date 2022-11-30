class FormResponse
  attr_reader :errors, :extra, :serialize_error_details_only

  def initialize(success:, errors: {}, extra: {}, serialize_error_details_only: false)
    @success = success
    @errors = errors.is_a?(ActiveModel::Errors) ? errors.messages.to_hash : errors
    @error_details = errors.details if errors.is_a?(ActiveModel::Errors)
    @extra = extra
    @serialize_error_details_only = serialize_error_details_only
  end

  def success?
    @success
  end

  def to_h
    hash = { success: success }
    hash[:errors] = errors if !serialize_error_details_only
    hash[:error_details] = flatten_details(error_details) if error_details.present?
    hash.merge!(extra)
    hash
  end

  def merge(other)
    self.class.new(
      success: success? && other.success?,
      errors: errors.merge(other.errors, &method(:merge_arrays)),
      extra: extra.merge(other.extra),
    ).tap do |merged_response|
      own_details = error_details
      other_details = other.instance_eval { error_details } if other.is_a?(self.class)
      merged_response.instance_eval do
        @error_details = Hash(own_details).merge(Hash(other_details), &method(:merge_arrays))
      end
    end
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
    details.transform_values { |errors| errors.pluck(:error) }
  end

  attr_reader :success
  attr_accessor :error_details
end
