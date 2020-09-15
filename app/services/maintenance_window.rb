class MaintenanceWindow
  attr_reader :start, :finish, :now

  def initialize(start:, finish:, now: nil, display_time_zone: 'America/New_York')
    @start = parse(start, display_time_zone: display_time_zone)
    @finish = parse(finish, display_time_zone: display_time_zone)
    @now = now || Time.zone.now
  end

  def active?
    (start...finish).cover?(now) if start && finish
  end

  private

  def parse(time_str, display_time_zone:)
    Time.zone.parse(time_str).in_time_zone(display_time_zone) if time_str.present?
  end
end
