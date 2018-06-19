# monkeypatch to prevent new relic from truncating backtraces.
# stack length is not currently configurable in new relic.
# The MAX_BACKTRACE_FRAMES constant is commented out for reference

module NewRelic
  module Agent
    class ErrorCollector
      # Maximum number of frames in backtraces. May be made configurable
      # in the future.
      # MAX_BACKTRACE_FRAMES = 50
      def truncate_trace(trace, _keep_frames = nil)
        trace
      end
    end
  end
end
