class FlashComponent < BaseComponent
  VALID_FLASH_TYPES = %w[error info success warning other notice alert].freeze

  attr_reader :flash

  def initialize(flash:)
    @flash = flash
  end

  def alerts
    flash.
      to_hash.
      slice(*VALID_FLASH_TYPES).
      select { |_flash_type, message| message.present? }.
      map { |flash_type, message| [alert_type(flash_type), message] }
  end

  def alert_type(flash_type)
    case flash_type
    when 'notice'
      :info
    when 'alert'
      :error
    else
      flash_type.to_sym
    end
  end
end
