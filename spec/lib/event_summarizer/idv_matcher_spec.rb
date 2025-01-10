require 'active_support'
require 'active_support/time'

require 'event_summarizer/idv_matcher'

RSpec.describe EventSummarizer::IdvMatcher do
  describe '#handle_cloudwatch_event' do
    let(:event) do
      {
        '@timestamp': '2024-01-02T03:04:05Z',
      }
    end

    subject(:matcher) do
      described_class.new
    end

    around do |example|
      Time.use_zone('UTC') do
        example.run
      end
    end

    context 'On unknown event' do
      let(:event) { super().merge('name' => 'Some random event') }
      it 'does not throw' do
        matcher.handle_cloudwatch_event(event)
      end
    end

    context "On 'IdV: doc auth welcome submitted' event" do
      let(:event) { super().merge('name' => 'IdV: doc auth welcome submitted') }

      it 'starts a new IdV attempt' do
        matcher.handle_cloudwatch_event(event)
        expect(matcher.current_idv_attempt).not_to eql(nil)
      end

      context 'with an IdV attempt already started' do
        before do
          allow(matcher).to receive(:current_idv_attempt).and_return(
            EventSummarizer::IdvMatcher::IdvAttempt.new(
              started_at: Time.zone.now,
            ),
          )
        end

        it 'finishes it' do
          expect(matcher.idv_attempts.length).to eql(0)
          matcher.handle_cloudwatch_event(event)
          expect(matcher.idv_attempts.length).to eql(1)
        end
      end
    end
  end
end
