require 'json'
require 'event_summarizer/vendor_result_evaluators/socure_doc_v'

RSpec.describe EventSummarizer::VendorResultEvaluators::SocureDocV do
  subject(:evaluation) do
    described_class.evaluate_result(docv_alert)
  end
  let(:success) { false }
  let(:vendor_name) { 'Unused' }
  let(:document_type) { 'Student ID' }
  let(:bullet) { "#{' ' * 17}- " }
  let(:docv_alert) do
    {
      success:,
      vendor_name:,
      document_type:,
      reason_codes:,
    }
  end
  describe 'failed result' do
    context 'general failure' do
      let(:reason_codes) { %w[I800 I827 I830 I999 I999] }

      it 'returns the correct result' do
        expect(evaluation).to eql(
          {
            type: :socure_docv_failures,
            description: "Socure DocV request failed (document_type: #{document_type}):",
          },
        )
      end
    end

    context 'itemized failure' do
      let(:reason_codes) { %w[I800 R827 I830 R999 I999] }

      it 'returns the correct result' do
        expect(evaluation).to eql(
          {
            type: :socure_docv_failures,
            description: "Socure DocV request failed (document_type: #{document_type}):" \
              "\n#{bullet}R827: Document is expired" \
              "\n#{bullet}R999: ",
          },
        )
      end
    end
  end
end
