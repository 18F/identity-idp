class EasternTimePresenter
  def initialize(timestamp)
    @timestamp = timestamp
  end

  def to_s
    # i18n-tasks-use t('date.month_names')
    I18n.t(
      'event_types.eastern_timestamp',
      timestamp: I18n.l(eastern_timestamp, format: :event_timestamp),
    )
  end

  private

  attr_reader :timestamp

  def eastern_timestamp
    timestamp.in_time_zone('Eastern Time (US & Canada)')
  end
end
