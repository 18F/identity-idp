class MemorableDateComponent < BaseComponent
    attr_reader :month, :day, :year, :hint, :label

    def initialize(month:, day:, year:, hint:, label:)
        @month = month
        @day = day
        @year = year
        @hint = hint
        @label = label
    end
end