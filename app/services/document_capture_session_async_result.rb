# frozen_string_literal: true

# Used in async document capture flow by LambdaJobs::Runner/Idv::Proofing.document_job_class
DocumentCaptureSessionAsyncResult = RedactedStruct.new(
  :id,
  :status,
  :result,
  :pii,
  keyword_init: true,
  allowed_members: [:id, :status, :result],
) do
  self::IN_PROGRESS = 'in_progress'
  self::DONE = 'done'
  self::TIMED_OUT = 'timed_out'

  def self.redis_key_prefix
    'dcs-async:result'
  end

  def self.timed_out
    new(status: DocumentCaptureSessionAsyncResult::TIMED_OUT)
  end

  def timed_out?
    status == DocumentCaptureSessionAsyncResult::TIMED_OUT
  end

  def done?
    status == DocumentCaptureSessionAsyncResult::DONE
  end

  def success?
    done? && result[:success]
  end

  def in_progress?
    status == DocumentCaptureSessionAsyncResult::IN_PROGRESS
  end

  alias_method :pii_from_doc, :pii
end
