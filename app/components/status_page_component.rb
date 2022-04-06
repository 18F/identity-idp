class StatusPageComponent < BaseComponent
  ICONS = {
    info: [:question],
    warning: [nil],
    error: [nil, :lock],
  }.freeze

  renders_one :header, ::PageHeadingComponent
  renders_many :action_buttons, ->(**button_options) do
    ButtonComponent.new(**button_options, big: true, wide: true)
  end
  renders_one :troubleshooting_options, TroubleshootingOptionsComponent

  attr_reader :status, :icon

  def initialize(status: :error, icon: nil)
    if !ICONS.key?(status)
      raise ArgumentError, "`status` #{status} is invalid, expected one of #{ICONS.keys}"
    end

    if !ICONS[status].include?(icon)
      raise ArgumentError, "`icon` #{icon} is invalid, expected one of #{ICONS[status]}"
    end

    @icon = icon
    @status = status
  end

  def icon_src
    image_path("status/#{[status, icon].compact.join('-')}")
  end

  def icon_alt
    # i18n-tasks-use t('components.status_page.icons.error')
    # i18n-tasks-use t('components.status_page.icons.question')
    # i18n-tasks-use t('components.status_page.icons.warning')
    # i18n-tasks-use t('components.status_page.icons.lock')
    t(icon || status, scope: [:components, :status_page, :icons])
  end
end
