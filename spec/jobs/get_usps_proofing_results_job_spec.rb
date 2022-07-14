require 'rails_helper'

RSpec.describe GetUspsProofingResultsJob do
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
            let(:pending_enrollments) {
                [
                    pending_enrollment,
                    pending_enrollment_2,
                    pending_enrollment_3,
                    pending_enrollment_4,
                ]
            }
            let(:passing_enrollment) { create(:in_person_enrollment, :passed) }

            let(:passing_response) { JSON.load_file (Rails.root.join "spec/fixtures/usps_ipp_responses/request_passed_proofing_results_response.json") }
            let(:failing_response) { JSON.load_file (Rails.root.join "spec/fixtures/usps_ipp_responses/request_failed_proofing_results_response.json") }
            let(:failing_unsupported_id_response){ 
                passing_response['primaryIdType'] = "Not supported"
                passing_response
                
                }
            let(:failing_enrollment_expired){ JSON.load_file (Rails.root.join "spec/fixtures/usps_ipp_responses/request_expired_proofing_results_response.json") }
            let(:no_post_office_visit_response) { JSON.load_file (Rails.root.join "spec/fixtures/usps_ipp_responses/request_no_post_office_proofing_results_response.json") }



            # todo refactor to ensure usages are covering the correct lines;
            # may need to switch to regular error with response double
            let(:progress_response_body) { JSON.load_file (Rails.root.join "spec/fixtures/usps_ipp_responses/request_in_progress_proofing_results_response.json") }
            let(:progress_response_error) {
                response = instance_double(Faraday::Response)
                allow(response).to receive(:[]).
                    with(:body).and_return(progress_response_body)
                Faraday::BadRequestError.new nil, response
            }
            let(:invalid_response) { "fubar" }

            before do
                allow(IdentityConfig.store).to receive(:in_person_proofing_enabled).
                    and_return(true)
            end

            it 'requests the enrollments that need their status checked' do
                allow(InPersonEnrollment).to receive(:needs_usps_status_check).
                    and_return([pending_enrollment])

                allow(proofer).to receive(:request_proofing_results).
                    with(pending_enrollment.usps_unique_id, pending_enrollment.enrollment_code).
                    and_return(invalid_response)

                allow(IdentityJobLogSubscriber.logger).to receive(:error)
                allow(IdentityJobLogSubscriber.logger).to receive(:warn)

                sut.perform Time.now

                expect(InPersonEnrollment).to have_received(:needs_usps_status_check).
                    with(
                        satisfy do |v|
                            v.begin === nil &&
                            v.end > 5.25.minutes.ago &&
                            v.end < 4.99.minutes.ago
                        end
                    ),
                    "expected call to InPersonEnrollment#needs_usps_status_check with beginless"\
                    " range starting about 5 minutes ago"
            end

            it 'records the last attempted status check regardless of response code and contents' do
                expect(pending_enrollments.pluck(:status_check_attempted_at)).to (all (eq nil)),
                    "failed test precondition: pending enrollments must not have status check time set"

                allow(InPersonEnrollment).to receive(:needs_usps_status_check).
                    and_return(pending_enrollments)

                allow(IdentityJobLogSubscriber.logger).to receive(:error)
                allow(IdentityJobLogSubscriber.logger).to receive(:warn)

                allow(proofer).to receive(:request_proofing_results).
                    with(pending_enrollment.usps_unique_id, pending_enrollment.enrollment_code).
                    and_return(failing_response)

                allow(proofer).to receive(:request_proofing_results).
                    with(pending_enrollment_2.usps_unique_id, pending_enrollment_2.enrollment_code).
                    and_raise(progress_response_error)

                allow(proofer).to receive(:request_proofing_results).
                    with(pending_enrollment_3.usps_unique_id, pending_enrollment_3.enrollment_code).
                    and_raise(progress_response_error)

                allow(proofer).to receive(:request_proofing_results).
                    with(pending_enrollment_4.usps_unique_id, pending_enrollment_4.enrollment_code).
                    and_return(failing_response)

                start_time = Time.now

                sut.perform Time.now

                expected_range = (start_time)...(Time.now)

                expect(
                    pending_enrollments.
                    map(&:reload). # Force reload records from DB
                    pluck(:status_check_attempted_at)
                ).to (all(
                    satisfy do |i| 
                        expected_range.cover?(i)
                    end
                )),
                "job must update status check time for all pending enrollments; found exception(s): #{pending_enrollments.inspect}"
            end

            it 'updates the enrollment record on 2xx responses with valid JSON' do
                allow(InPersonEnrollment).to receive(:needs_usps_status_check).
                    and_return([pending_enrollment])

                allow(proofer).to receive(:request_proofing_results).
                    with(pending_enrollment.usps_unique_id, pending_enrollment.enrollment_code).
                    and_return(passing_response)

                start_time = Time.now

                sut.perform Time.now

                expected_range = (start_time)...(Time.now)
                
                pending_enrollment.reload

                expect(pending_enrollment.status).to eq "passed"
                expect(pending_enrollment.status_updated_at).to satisfy do |i|
                    expected_range.cover?(i)
                end
            end

            it 'reports a high-priority error on 2xx responses with invalid JSON' do
                allow(InPersonEnrollment).to receive(:needs_usps_status_check).
                    and_return([pending_enrollment])

                allow(proofer).to receive(:request_proofing_results).
                    with(pending_enrollment.usps_unique_id, pending_enrollment.enrollment_code).
                    and_return(invalid_response)

                expect(IdentityJobLogSubscriber.logger).to receive(:error)
                    .with(
                        {
                            name: 'get_usps_proofing_results_job.errors.bad_response_structure',
                            enrollment_id: pending_enrollment.id,
                        }.to_json,
                    )

                start_time = Time.now

                sut.perform Time.now

                pending_enrollment.reload

                expect(pending_enrollment.status).to eq "pending"
            end

            # todo does this mean all 4xx responses, or only the ones we don't cover?
            it 'reports a low-priority error on 4xx responses' do
                allow(InPersonEnrollment).to receive(:needs_usps_status_check).
                    and_return([pending_enrollment])

                err = Faraday::BadRequestError.new nil, nil
    

                allow(proofer).to receive(:request_proofing_results).
                    with(pending_enrollment.usps_unique_id, pending_enrollment.enrollment_code) do |_,__|
                        raise err
  
                    end

                expect(IdentityJobLogSubscriber.logger).to receive(:warn).
                    with(
                        satisfy do |event|
                            expect(event).to be_instance_of(String)
                            parsed_event = JSON.parse(event)
                            expect(parsed_event).to be_instance_of(Hash).
                            and include(
                                "name" => 'get_usps_proofing_results_job.errors.request_exception',
                                "enrollment_id" => pending_enrollment.id,
                                "exception" => include(
                                    "class" => err.class.to_s,
                                    "message" => err.message,
                                    "backtrace" => instance_of(Array),
                                ),
                            )
                        end
                    )
                
                start_time = Time.now

                sut.perform Time.now

                pending_enrollment.reload

                expect(pending_enrollment.status).to eq "pending"
            end

            it 'marks enrollments as expired when USPS says they have expired' do
                error = Faraday::BadRequestError.new({body:failing_enrollment_expired})
                allow(proofer).to receive(:request_proofing_results).
                with(pending_enrollment.usps_unique_id, pending_enrollment.enrollment_code).
                and_raise(error)

                allow(InPersonEnrollment).to receive(:needs_usps_status_check).
                and_return([pending_enrollment])

                start_time = Time.now

                sut.perform Time.now

                pending_enrollment.reload

                expect(pending_enrollment.status).to eq "expired"


                
            end

            it 'ignores enrollments when USPS says the customer has not been to the post office' do
                error = Faraday::BadRequestError.new({body:no_post_office_visit_response})
                allow(proofer).to receive(:request_proofing_results).
                with(pending_enrollment.usps_unique_id, pending_enrollment.enrollment_code).
                and_raise(error)

                allow(InPersonEnrollment).to receive(:needs_usps_status_check).
                and_return([pending_enrollment])

                start_time = Time.now

                sut.perform Time.now

                pending_enrollment.reload

                #not sure if this should equal pending
                expect(pending_enrollment.status).to eq "pending"
            end

            #not clear on the logic. How do you validate its mimicking a 5xx response
            it 'reports a high-priority error on 5xx responses' do
                    allow(InPersonEnrollment).to receive(:needs_usps_status_check).
                        and_return([pending_enrollment])
    
                    err = Faraday::ServerError.new nil, nil


                    allow(proofer).to receive(:request_proofing_results).
                    with(pending_enrollment.usps_unique_id, pending_enrollment.enrollment_code) do |_,__|
                        raise err
                    end

                expect(IdentityJobLogSubscriber.logger).to receive(:error).
                    with(
                        satisfy do |event|
                            expect(event).to be_instance_of(String)
                            parsed_event = JSON.parse(event)
                            expect(parsed_event).to be_instance_of(Hash).
                            and include(
                                "name" => 'get_usps_proofing_results_job.errors.request_exception',
                                "enrollment_id" => pending_enrollment.id,
                                "exception" => include(
                                    "class" => err.class.to_s,
                                    "message" => err.message,
                                    "backtrace" => instance_of(Array),
                                ),
                            )
                        end
                    )

                start_time = Time.now

                sut.perform Time.now

                pending_enrollment.reload

                expect(pending_enrollment.status).to eq "pending"
                    
            end
            
            it 'retroactively fails enrollment for unsupported ID types' do
                allow(proofer).to receive(:request_proofing_results).
                with(pending_enrollment.usps_unique_id, pending_enrollment.enrollment_code).
                and_return(failing_unsupported_id_response)
            
                allow(InPersonEnrollment).to receive(:needs_usps_status_check).
                and_return([pending_enrollment])
                expect(pending_enrollment.status).to eq "pending"

                sut.perform Time.now
                #forces to reload from database
                pending_enrollment.reload

                expect(pending_enrollment.status).to eq "failed"

            end
        end

        describe 'IPP disabled' do
                let(:proofer) {
                    uipp = instance_double(UspsInPersonProofer)
                    expect(UspsInPersonProofer).to_not receive(:new)
                    uipp
                }
            before do
                allow(IdentityConfig.store).to receive(:in_person_proofing_enabled).
                    and_return(false)
            end

            it 'does not request any enrollment records' do
                expect(proofer).to_not receive(:request_proofing_results)

                sut.perform Time.now

            end
        end
    end

end