class TimeComponent < BaseComponent
  attr_reader :time, :tag_options

  def initialize(time:, **tag_options)
    @time = time
    @tag_options = tag_options
  end

  def formatted_time
    time.strftime(t('time.formats.event_timestamp'))
  end
end
