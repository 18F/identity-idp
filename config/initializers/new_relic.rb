# monkeypatch to prevent new relic from truncating backtraces.  length is not configurable
module NewRelic
  module Agent
    class ErrorCollector
      # Maximum number of frames in backtraces. May be made configurable
      # in the future.
      MAX_BACKTRACE_FRAMES = 50
      def truncate_trace(trace, _keep_frames = MAX_BACKTRACE_FRAMES)
        trace
      end
    end
  end
end
