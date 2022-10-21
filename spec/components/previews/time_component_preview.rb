class TimeComponentPreview < BaseComponentPreview
  # @!group Preview
  def default
    render TimeComponent.new(time: Time.zone.now + 5.hours)
  end
  # @!endgroup

  # @param time datetime-local
  def workbench(time: Time.zone.now + 5.hours)
    render TimeComponent.new(time: time)
  end
end
