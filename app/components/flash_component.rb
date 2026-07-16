# frozen_string_literal: true

class FlashComponent < BaseComponent
  VALID_FLASH_TYPES = %w[error info success warning other notice alert session_timed_out].freeze
  TOAST_FLASH_TYPES = %w[success notice].freeze

  attr_reader :flash

  def initialize(flash:)
    @flash = flash
  end

  def alerts
    @alerts ||= messages
      .reject { |flash_type, _message| toast_type?(flash_type) }
      .map { |flash_type, message| [alert_type(flash_type), message] }
  end

  def toasts
    @toasts ||= messages
      .select { |flash_type, _message| toast_type?(flash_type) }
      .map { |_flash_type, message| message }
  end

  def render?
    alerts.any? || toasts.any?
  end

  def alerts?
    alerts.any?
  end

  def alert_type(flash_type)
    case flash_type
    when 'alert', 'error'
      :error
    when 'warning'
      :warning
    else
      :neutral
    end
  end

  private

  def messages
    @messages ||= flash
      .to_hash
      .slice(*VALID_FLASH_TYPES)
      .select { |_flash_type, message| message.present? }
  end

  def toast_type?(flash_type)
    TOAST_FLASH_TYPES.include?(flash_type)
  end
end
