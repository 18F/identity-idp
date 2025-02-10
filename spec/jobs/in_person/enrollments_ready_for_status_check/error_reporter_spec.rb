require 'rails_helper'

RSpec.describe InPerson::EnrollmentsReadyForStatusCheck::ErrorReporter do
  let(:class_name_suffix) { "TestClass#{[*('A'..'Z'), *('a'..'z')].sample(10).join}" }

  # We need the class name since it's part of what we're logging
  let(:class_name) { "#{described_class.name.demodulize}#{class_name_suffix}" }

  let(:analytics) { FakeAnalytics.new }
  subject(:error_reporter) { described_class.new(class_name, analytics) }
  let(:analytics_extra) { nil }
  let(:expected_error_class) { nil }
  let(:expected_message) { nil }

  before(:each) do
    allow(analytics).to receive(
      :idv_in_person_proofing_enrollments_ready_for_status_check_job_ingestion_error,
    )
    allow(NewRelic::Agent).to receive(:notice_error)
  end

  def it_generates_and_records_the_error
    expect(analytics).to have_received(
      :idv_in_person_proofing_enrollments_ready_for_status_check_job_ingestion_error,
    ).once do |exception_class:, exception_message:, **_extra|
      expect(exception_class).to eq(expected_error_class)
      expect(exception_message).to eq(expected_message)
    end
    expect(NewRelic::Agent).to have_received(:notice_error).once do |error|
      expect(error).to be_instance_of(expected_error_class)
      expect(error.message).to eq(expected_message)
    end
  end

  def it_passes_expected_attributes_to_analytics
    expect(analytics).to have_received(
      :idv_in_person_proofing_enrollments_ready_for_status_check_job_ingestion_error,
    ).once do |exception_class:, exception_message:, **extra|
      expect(extra).to eq(analytics_extra)
    end
  end

  describe '#report_error' do
    context 'given a string message' do
      let(:string_message) { 'my string message here' }
      let(:expected_error_class) { RuntimeError }
      let(:expected_message) { "#{class_name}: #{string_message}" }
      let(:analytics_extra) { {} }

      before(:each) do
        error_reporter.report_error(string_message, **analytics_extra)
      end

      it 'generates an error object and records the error' do
        it_generates_and_records_the_error
      end
      it 'passes the expected data to analytics' do
        it_passes_expected_attributes_to_analytics
      end

      context 'with extra analytics data' do
        let(:analytics_extra) { { test: 'abcd' } }

        it 'generates an error object and records the error' do
          it_generates_and_records_the_error
        end
        it 'passes the expected data to analytics' do
          it_passes_expected_attributes_to_analytics
        end
      end
    end

    context 'given an error' do
      let(:error) { ArgumentError.new(expected_message) }
      let(:expected_error_class) { ArgumentError }
      let(:expected_message) { 'my test message' }
      let(:analytics_extra) { {} }

      before(:each) do
        error_reporter.report_error(error, **analytics_extra)
      end

      it 'generates an error object and records the error' do
        it_generates_and_records_the_error
      end
      it 'passes the expected data to analytics' do
        it_passes_expected_attributes_to_analytics
      end

      context 'with extra analytics data' do
        let(:analytics_extra) { { test: 'abcd' } }

        it 'generates an error object and records the error' do
          it_generates_and_records_the_error
        end
        it 'passes the expected data to analytics' do
          it_passes_expected_attributes_to_analytics
        end
      end
    end
  end
end
