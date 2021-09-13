class AlertComponent < BaseComponent
  attr_reader :type, :extra_classes

  validates :type, inclusion: { in: %w[info success warning error other] }

  def initialize(type: nil, message: nil, **args)
    @type = type
    @extra_classes = args[:class]
    @message = message
  end

  def role
    if type === 'error'
      'alert'
    else
      'status'
    end
  end

  def classes
    ['usa-alert', "usa-alert--#{type}", *extra_classes]
  end

  def message
    content.presence || @message
  end
end
