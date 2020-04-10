class MultiHealthChecker
  def initialize(checkers)
    @checkers = checkers.to_h
  end

  def check
    statuses = checkers.map { |name, checker| [name, checker.check] }.to_h

    MultiHealthCheckerSummary.new(statuses)
  end

  private

  attr_reader :checkers
end
