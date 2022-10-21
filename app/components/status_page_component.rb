class StatusPageComponent < BaseComponent
  ICONS = {
    info: [:question],
    warning: [nil],
    error: [nil, :lock],
  }.freeze

  VALID_STATUS = %i[info error warning].freeze

  renders_one :header, ::PageHeadingComponent
  renders_many :action_buttons, ->(**button_options) do
    ButtonComponent.new(**button_options, big: true, wide: true)
  end
  renders_one :troubleshooting_options, TroubleshootingOptionsComponent

  attr_reader :status, :icon

  def initialize(status: :error, icon: nil)
    if !VALID_STATUS.include?(status)
      raise ArgumentError, "`status` #{status} is invalid, expected one of #{VALID_STATUS}"
    end

    if !ICONS[status].include?(icon)
      raise ArgumentError, "`icon` #{icon} is invalid, expected one of #{ICONS[status]}"
    end

    @icon = icon
    @status = status
  end

  def icon_name
    if @icon
      "#{status}_#{icon}".to_sym
    else
      status.to_sym
    end
  end
end
