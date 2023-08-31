module IrsAttemptsApiTrackingHelper
  def stub_attempts_tracker
    irs_attempts_api_tracker = FakeAttemptsTracker.new

    if respond_to?(:controller)
      allow(controller).to receive(:irs_attempts_api_tracker).and_return(irs_attempts_api_tracker)
    else
      allow(self).to receive(:irs_attempts_api_tracker).and_return(irs_attempts_api_tracker)
    end

    @irs_attempts_api_tracker = irs_attempts_api_tracker
  end
end
