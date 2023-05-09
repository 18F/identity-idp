require 'rails_helper'

RSpec.describe InPerson::EnrollmentsReadyForStatusCheck::UsesReportError do
  let(:class_name) { "#{described_class.name}TestClass" }
  let(:class_ref) { Object.const_set(class_name, Class.new.include(described_class)) }
  subject(:uses_report_error) { class_ref.new }
  let(:analytics) { instance_double(Analytics) }

  before(:each) do
    allow(uses_report_error).to receive(:analytics).and_return(analytics)
  end

  describe '#report_error' do
    context 'given a string message' do
      let(:string_message) { 'my string message here' }

      it 'generates an error object and records the error' do
        expect(analytics).to receive(
          :idv_in_person_proofing_enrollments_ready_for_status_check_job_ingestion_error,
        ) do |error, **extra|
          expect(error).to be_instance_of(StandardError)
          expect(error.name).to be("#{class_name}: #{string_message}")
        end
        expect(NewRelic::Agent).to receive(:notice_error) do |error|
          expect(error).to be_instance_of(StandardError)
          expect(error.name).to be("#{class_name}: #{string_message}")
        end
        uses_report_error(string_message)
      end
    end
  end
end
