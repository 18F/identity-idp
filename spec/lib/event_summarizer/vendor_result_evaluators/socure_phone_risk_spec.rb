require 'event_summarizer/vendor_result_evaluators/socure_phone_risk'

RSpec.describe EventSummarizer::VendorResultEvaluators::SocurePhoneRisk do
  describe '.evaluate_result' do
    subject { described_class }

    let(:description_bullet) { "#{' ' * 17}- " }
    let(:reason_codes) { nil }
    let(:timeout) { false }
    let(:result) do
      {
        'success' => success,
        'timeout' => timeout,
        'vendor' => {
          'result' => {
            'phonerisk' => {
              'reason_codes' => reason_codes,
            },
          },
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
    end
  end
end
