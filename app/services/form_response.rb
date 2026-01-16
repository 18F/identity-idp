# frozen_string_literal: true

class FormResponse
  attr_reader :errors, :extra

  def initialize(success:, errors: nil, extra: {})
    @success = success
    @errors = errors.is_a?(ActiveModel::Errors) ? errors.messages.to_hash : errors.to_h
    @error_details = errors&.details if !errors.is_a?(Hash)
    @extra = extra
  end

  def success?
    @success
  end

  def to_h
    hash = { success: success }
    hash[:errors] = errors.presence if !defined?(@error_details)
    hash[:error_details] = flatten_details(error_details) if error_details.present?
    hash.merge!(extra)
    hash
  end

  alias_method :to_hash, :to_h

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

  def first_error_message(key = nil)
    return if errors.blank?
    key ||= errors.keys.first
    errors[key].first
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
    details.transform_values do |errors|
      errors.map { |error| error[:type] || error[:error] }.index_with(true)
    end
  end

  attr_reader :success
  attr_accessor :error_details
end
