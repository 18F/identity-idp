# frozen_string_literal: true

class AlertIconComponent < BaseComponent
  ICON_SOURCE = {
    warning: 'status/warning.svg',
    error: 'status/error.svg',
    error_lock: 'status/error-lock.svg',
    personal_key: 'status/personal-key.svg',
    info_question: 'status/info-question.svg',
    delete: 'status/delete.svg',
  }.freeze
  DEFAULT_WIDTH = 88
  DEFAULT_HEIGHT = 88

  attr_reader :tag_options, :icon_name

  validates_inclusion_of :icon_name, in: ICON_SOURCE.keys

  def initialize(icon_name: :warning, **tag_options)
    @icon_name = icon_name
    @tag_options = tag_options
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
    { width: DEFAULT_WIDTH, height: DEFAULT_HEIGHT }
  end
end
