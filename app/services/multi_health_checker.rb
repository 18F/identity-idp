class MultiHealthChecker
  Summary = Struct.new(:statuses) do
    def healthy?
      statuses.values.all?(&:healthy?)
    end

    def to_h
      super.merge(healthy: healthy?)
    end

    def as_json(*args)
      to_h.as_json(*args)
    end
  end

  def initialize(checkers)
    @checkers = checkers.to_h
  end

  def check
    statuses = checkers.map { |name, checker| [name, checker.check] }.to_h

    Summary.new(statuses)
  end

  private

  attr_reader :checkers
end
