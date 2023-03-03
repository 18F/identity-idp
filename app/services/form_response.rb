class FormResponse
  attr_reader :errors, :extra, :serialize_error_details_only

  alias_method :serialize_error_details_only?, :serialize_error_details_only

  def initialize(success:, errors: {}, extra: {}, serialize_error_details_only: false)
    @success = success
    @original_errors = errors
    @errors = errors.is_a?(ActiveModel::Errors) ? errors.messages.to_hash : errors
    @error_details = errors.details if errors.is_a?(ActiveModel::Errors)
    @extra = extra
    @serialize_error_details_only = serialize_error_details_only
  end

  def success?
    @success
  end

  def analytics_hash
    return to_h unless @original_errors.is_a?(ActiveModel::Errors)
    hash = { success: success }
    pii_like_keypaths = []
    if !serialize_error_details_only?
      hash[:errors] = @original_errors.errors.map do |err|
        if HIDDEN_MESSAGE_ERROR_TYPES.include?(err.type)
          pii_like_keypaths.append([:errors, err.attribute])
          [err.attribute, err.type.to_s]
        else
          [err.attribute, err.message]
        end
      end.to_h
    end
    if error_details.present?
      hash[:error_details] = @original_errors.errors.map do |err|
        if HIDDEN_MESSAGE_ERROR_TYPES.include?(err.type)
          pii_like_keypaths.append([:error_details, err.attribute])
          [err.attribute, err.type.to_s]
        else
          [err.attribute, err.message]
        end
      end.to_h
    end
    hash[:pii_like_keypaths] = pii_like_keypaths
    hash.merge!(extra)
    hash
  end

  def to_h
    hash = { success: success }
    hash[:errors] = errors if !serialize_error_details_only?
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

  # Types of errors to hide from the logs (replace message with type)
  HIDDEN_MESSAGE_ERROR_TYPES = %i[nontransliterable_field]

  def merge_arrays(_key, first, second)
    Array(first) + Array(second)
  end

  def flatten_details(details)
    details.transform_values { |errors| errors.pluck(:error) }
  end

  attr_reader :success
  attr_accessor :error_details
end
