require 'time'

module IdentityIdpFunctions
  class Timer
    attr_reader :results

    def initialize
      @results = {}
    end

    def time(name)
      start = Time.now.to_f

      yield
    ensure
      results[name] = ((Time.now.to_f - start) * 1000).round(2)
    end
  end
end
