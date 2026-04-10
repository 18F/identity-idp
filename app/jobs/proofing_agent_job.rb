# frozen_string_literal: true

class ProofingAgentJob < ApplicationJob
  include JobHelpers::StaleJobHelper

  queue_as :high_proofing_agent

  discard_on JobHelpers::StaleJobHelper::StaleJobError

  def perform(
  )
    timer = JobHelpers::Timer.new

    raise_stale_job! if stale_job?(enqueued_at)
  end

  private

  def make_vendor_proofing_requests
    call_aamva_verification if applicant.state_id.present?
    call_passport_verification if applicant.passport.present?
    call_resolution_proofing_job
  end

  def call_aamva_verification
  end

  def call_passport_verification
  end

  def call_resolution_proofing_job
    ResolutionProofingJob.perform_now(**job_arguments)
  end
end
