class AlertIconComponent < BaseComponent
  ICON_SOURCE = {
    warning: 'status/warning.svg',
    error: 'status/error.svg',
    error_lock: 'status/error-lock.svg',
    personal_key: 'personal-key/personal-key.svg',
    info_question: 'status/info-question.svg',
    delete: 'status/delete.svg',
  }

  attr_reader :tag_options

  def initialize(icon_name: :warning, **tag_options)
    if !ICON_SOURCE.key?(icon_name)
      raise ArgumentError,
            "`icon_name` #{icon_name} is invalid, expected one of #{ICON_SOURCE.keys}"
    end
    @tag_options = tag_options
    @tag_options[:class] = css_class
  end

  def render?
    ICON_SOURCE.key?(@icon_name)
  end

  def source
    asset_url(ICON_SOURCE[@icon_name])
  end

  def alt_text
    t("image_description.#{@icon_name}")
  end

  def css_class
    classes = [*@tag_options[:class]]
    classes << 'alert-icon'
    classes
  end
end
