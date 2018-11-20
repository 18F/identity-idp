class UtcTimePresenter
  def initialize(timestamp)
    @timestamp = timestamp
  end

  def to_s
    # i18n-tasks-use t('date.month_names')
    I18n.l(timestamp, format: :event_timestamp)
  end

  private

  attr_reader :timestamp
end
