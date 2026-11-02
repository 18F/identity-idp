require 'event_summarizer/vendor_result_evaluators/socure_phone_risk'

RSpec.describe EventSummarizer::VendorResultEvaluators::SocurePhoneRisk do
  describe '.evaluate_result' do
    subject { described_class }

    let(:description_bullet) { "#{' ' * 17}- " }
    let(:reason_codes) { nil }
    let(:timeout) { false }
    let(:vendor_result) do
      {
        'phonerisk' => {
          'reason_codes' => reason_codes,
        },
      }
    end
    let(:result) do
      {
        'success' => success,
        'timeout' => timeout,
        'vendor' => {
          'result' => vendor_result,
        },
      }
    end

    context 'when the result is successful' do
      let(:success) { true }

      it 'returns a success hash' do
        expect(subject.evaluate_result(result)).to eq(
          {
            type: :socure_phonerisk_success,
            description: 'Socure Phone Risk call succeeded',
          },
        )
      end
    end

    context 'when the result is not successful' do
      let(:success) { false }

      context 'when the result is a timeout' do
        let(:timeout) { true }

        it 'returns a timeout response' do
          expect(subject.evaluate_result(result)).to eq(
            {
              type: :socure_phonerisk_timeout,
              description: 'Socure Phone Risk call timed out',
            },
          )
        end
      end

      context 'when the result is not a timeout' do
        let(:timeout) { false }

        context 'when reason codes are present' do
          let(:reason_codes) do
            {
              'I600' => 'Some numbers match',
              'R800' => 'I am error',
              'R801' => 'Identity not associated',
            }
          end

          it 'returns a failure hash' do
            expect(subject.evaluate_result(result)).to eq(
              type: :socure_phonerisk_failures,
              description: "Socure Phone Risk request failed:" \
              "\n#{description_bullet}R800: I am error" \
              "\n#{description_bullet}R801: Identity not associated",
            )
          end
        end
      end

      context 'when reason codes are not present' do
        let(:reason_codes) { nil }

        it 'returns a failure hash' do
          expect(subject.evaluate_result(result)).to eq(
            type: :socure_phonerisk_failures,
            description: 'Socure Phone Risk request failed: Without reason codes',
          )
        end
      end

      context 'when the vendor returned decision verdicts' do
        let(:name_correlation_successful) { true }
        let(:name_phone_correlation_score) { 0.95 }
        let(:phonerisk_successful) { true }
        let(:phonerisk_score) { 0.1 }
        let(:autofail_reason_codes) { [] }
        let(:vendor_result) do
          {
            'phonerisk' => {
              'reason_codes' => reason_codes,
              'score' => phonerisk_score,
            },
            'name_phone_correlation' => {
              'score' => name_phone_correlation_score,
            },
            'name_correlation_successful' => name_correlation_successful,
            'phonerisk_successful' => phonerisk_successful,
            'autofail_reason_codes' => autofail_reason_codes,
          }
        end

        context 'when the name-phone correlation score was below the threshold' do
          let(:name_correlation_successful) { false }
          let(:name_phone_correlation_score) { 0.79 }

          it 'names the failed check and its score' do
            expect(subject.evaluate_result(result)).to eq(
              type: :socure_phonerisk_failures,
              description: 'Socure Phone Risk request failed: ' \
                           'Name-phone correlation failed (score: 0.79)',
            )
          end
        end

        context 'when the phone risk score was above the threshold' do
          let(:phonerisk_successful) { false }
          let(:phonerisk_score) { 0.9 }

          it 'names the failed check and its score' do
            expect(subject.evaluate_result(result)).to eq(
              type: :socure_phonerisk_failures,
              description: 'Socure Phone Risk request failed: Phone risk failed (score: 0.9)',
            )
          end
        end

        context 'when automatic-failure reason codes matched' do
          let(:reason_codes) { { 'R617' => 'Phone is associated with elevated risk' } }
          let(:autofail_reason_codes) { ['R617'] }

          it 'names the matched codes alongside their descriptions' do
            expect(subject.evaluate_result(result)).to eq(
              type: :socure_phonerisk_failures,
              description: "Socure Phone Risk request failed: " \
                           "Matched automatic-failure reason codes: R617" \
                           "\n#{description_bullet}R617: Phone is associated with elevated risk",
            )
          end
        end

        context 'when every check failed' do
          let(:name_correlation_successful) { false }
          let(:name_phone_correlation_score) { 0.79 }
          let(:phonerisk_successful) { false }
          let(:phonerisk_score) { 0.9 }
          let(:autofail_reason_codes) { %w[R617 R618] }

          it 'names each failed check' do
            expect(subject.evaluate_result(result)).to eq(
              type: :socure_phonerisk_failures,
              description: 'Socure Phone Risk request failed: ' \
                           'Name-phone correlation failed (score: 0.79); ' \
                           'Phone risk failed (score: 0.9); ' \
                           'Matched automatic-failure reason codes: R617, R618',
            )
          end
        end

        context 'when a check failed without a score' do
          let(:name_correlation_successful) { false }
          let(:name_phone_correlation_score) { nil }

          it 'names the failed check without a score' do
            expect(subject.evaluate_result(result)).to eq(
              type: :socure_phonerisk_failures,
              description: 'Socure Phone Risk request failed: Name-phone correlation failed',
            )
          end
        end
      end

      context 'when the vendor returned no result' do
        let(:result) { { 'success' => false } }

        it 'falls back to the reason code description' do
          expect(subject.evaluate_result(result)).to eq(
            type: :socure_phonerisk_failures,
            description: 'Socure Phone Risk request failed: Without reason codes',
          )
        end
      end
    end
  end
end
