# frozen_string_literal: true

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
  renders_one :footer, PageFooterComponent

  attr_reader :status, :icon

  validates_inclusion_of :status, in: %i[info error warning]
  validate :validate_status_icon

  def initialize(status: :error, icon: nil)
    @icon = icon
    @status = status
  end

  def icon_name
    if @icon
      :"#{status}_#{icon}"
    else
      status.to_sym
    end
  end

  private

  def validate_status_icon
    return if ICONS[status]&.include?(icon)
    errors.add(
      :icon,
      :invalid,
      message: "`icon` #{icon} is invalid, expected one of #{ICONS[status]}",
    )
  end
end
