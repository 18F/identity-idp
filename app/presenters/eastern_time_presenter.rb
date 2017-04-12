class EasternTimePresenter
  def initialize(timestamp)
    @timestamp = timestamp
  end

  def to_s
    I18n.t(
      'event_types.timestamp',
      date: eastern_timestamp.strftime('%B %e, %Y'),
      time: eastern_timestamp.strftime('%-l:%M %p')
    )
  end

  private

  attr_reader :timestamp

  def eastern_timestamp
    timestamp.in_time_zone('Eastern Time (US & Canada)')
  end
end
