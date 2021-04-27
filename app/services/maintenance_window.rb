class MaintenanceWindow
  attr_reader :start, :finish, :now

  def initialize(start:, finish:, now: nil, display_time_zone: 'America/New_York')
    @start = start.in_time_zone(display_time_zone) if start.present?
    @finish = finish.in_time_zone(display_time_zone) if finish.present?
    @now = now || Time.zone.now
  end

  def active?
    (start...finish).cover?(now) if start && finish
  end
end
