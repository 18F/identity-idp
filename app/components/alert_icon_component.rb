class AlertIconComponent < BaseComponent
  ICON_SOURCE = {
    warning: 'status/warning.svg',
    error: 'status/error.svg',
    error_lock: 'status/error-lock.svg',
    personal_key: 'status/personal-key.svg',
    info_question: 'status/info-question.svg',
    delete: 'status/delete.svg',
  }
  DEFAULT_WIDTH = 88
  DEFAULT_HEIGHT = 88

  attr_reader :tag_options, :icon_name

  def initialize(icon_name: :warning, **tag_options)
    if !ICON_SOURCE.key?(icon_name)
      raise ArgumentError,
            "`icon_name` #{icon_name} is invalid, expected one of #{ICON_SOURCE.keys}"
    end
    @icon_name = icon_name
    @tag_options = tag_options
    @tag_options[:width] ||= DEFAULT_WIDTH
    @tag_options[:height] ||= DEFAULT_HEIGHT
  end

  def render?
    ICON_SOURCE.key?(icon_name)
  end

  def source
    asset_url(ICON_SOURCE[icon_name])
  end

  def alt_text
    t("image_description.#{icon_name}")
  end

  def css_class
    classes = [*tag_options[:class]]
    classes << 'alert-icon'
    classes
  end

  def size_attributes
    if tag_options[:size].present?
      { size: tag_options[:size], width: nil, height: nil }
    else
      { width: tag_options[:width], height: tag_options[:height] }
    end
  end
end
