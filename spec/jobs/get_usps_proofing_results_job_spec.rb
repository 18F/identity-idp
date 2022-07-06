require 'rails_helper'

RSpec.describe GetUspsProofingResultsJob do
    # let(:ipp_class) { class_double(InPersonEnrollment) }
    let(:proofer) {
        uipp = instance_double(UspsInPersonProofer)
        expect(UspsInPersonProofer).to receive(:new).and_return(uipp)
        uipp
    }
    let(:sut) { GetUspsProofingResultsJob.new }

    describe '#perform' do
        describe 'IPP enabled' do
            let(:pending_enrollment) { create(:in_person_enrollment, enrollment_code: SecureRandom.hex(18)) }
            let(:pending_enrollment_2) { create(:in_person_enrollment, enrollment_code: SecureRandom.hex(18)) }
            let(:pending_enrollment_3) { create(:in_person_enrollment, enrollment_code: SecureRandom.hex(18)) }
            let(:pending_enrollment_4) { create(:in_person_enrollment, enrollment_code: SecureRandom.hex(18)) }
            let(:passing_enrollment) { create(:in_person_enrollment, :passed) }

            let(:passing_response) { JSON.load_file (Rails.root.join "spec/fixtures/usps_ipp_responses/request_passed_proofing_results_response.json") }
            let(:failing_response) { JSON.load_file (Rails.root.join "spec/fixtures/usps_ipp_responses/request_failed_proofing_results_response.json") }
            let(:progress_response) { JSON.load_file (Rails.root.join "spec/fixtures/usps_ipp_responses/request_in_progress_proofing_results_response.json") }
            let(:invalid_response) { "fubar" }

            before do
                allow(IdentityConfig.store).to receive(:in_person_proofing_enabled).
                    and_return(true)
            end

            it 'requests the enrollments that need their status checked' do
                allow(InPersonEnrollment).to receive(:needs_usps_status_check).
                    and_return([pending_enrollment])

                allow(proofer).to receive(:request_proofing_results).
                    with(pending_enrollment.usps_enrollment_id, pending_enrollment.enrollment_code).
                    and_return(invalid_response)

                sut.perform Time.now

                expect(InPersonEnrollment).to have_received(:needs_usps_status_check).
                    with(
                        satisfy do |v|
                            v.begin === nil &&
                            v.end > 5.25.minutes.ago &&
                            v.end < 4.99.minutes.ago
                        end
                    )
            end

            it 'records the last attempted status check regardless of response code and contents' do
                expect(pending_enrollment.status_check_attempted_at).to eq nil
                expect(pending_enrollment_2.status_check_attempted_at).to eq nil
                expect(pending_enrollment_3.status_check_attempted_at).to eq nil
                expect(pending_enrollment_4.status_check_attempted_at).to eq nil

                allow(InPersonEnrollment).to receive(:needs_usps_status_check).
                    and_return([pending_enrollment, pending_enrollment_2, pending_enrollment_3, pending_enrollment_4])

                allow(proofer).to receive(:request_proofing_results).
                    with(pending_enrollment.usps_enrollment_id, pending_enrollment.enrollment_code).
                    and_return(failing_response)

                allow(proofer).to receive(:request_proofing_results).
                    with(pending_enrollment_2.usps_enrollment_id, pending_enrollment_2.enrollment_code).
                    and_return(progress_response)

                allow(proofer).to receive(:request_proofing_results).
                    with(pending_enrollment_3.usps_enrollment_id, pending_enrollment_3.enrollment_code).
                    and_return(progress_response)

                allow(proofer).to receive(:request_proofing_results).
                    with(pending_enrollment_4.usps_enrollment_id, pending_enrollment_4.enrollment_code).
                    and_return(passing_response)

                start_time = Time.now

                sut.perform Time.now

                expected_range = (start_time)...(Time.now)

                expect(
                    [
                        pending_enrollment,
                        pending_enrollment_2,
                        pending_enrollment_3,
                        pending_enrollment_4,
                    ].
                    map(&:reload). # Force reload records from DB
                    pluck(:status_check_attempted_at)
                ).to all(
                    satisfy do |i| 
                        expected_range.cover?(i)
                    end
                )
            end

            it 'updates the enrollment record on 2xx responses with valid JSON' do
                skip
            end

            it 'reports a high-priority error on 2xx responses with invalid JSON' do
                skip
            end

            it 'reports a low-priority error on 4xx responses' do
                skip
            end

            it 'reports a high-priority error on 5xx responses' do
                skip
            end

            it 'retroactively fails enrollment for unsupported ID types' do
                skip
            end
        end

        describe 'IPP disabled' do
            before do
                allow(IdentityConfig.store).to receive(:in_person_proofing_enabled).
                    and_return(true)
            end

            it 'does not request any enrollment records' do
                skip
            end
        end
    end

end