class AlertComponent < BaseComponent
  VALID_TYPES = [:info, :success, :error, :other].freeze

  attr_reader :type, :message, :tag_options, :text_tag

  def initialize(type: :info, text_tag: 'p', message: nil, **tag_options)
    if !VALID_TYPES.include?(type)
      raise ArgumentError, "`type` of #{type} is invalid, expected one of #{VALID_TYPES}"
    end

    @type = type
    @message = message
    @tag_options = tag_options
    @text_tag = text_tag
  end

  def role
    if type == :error
      'alert'
    else
      'status'
    end
  end

  def content
    @message || super
  end
end
