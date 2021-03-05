# frozen_string_literal: true

# Used in async document capture flow by LambdaJobs::Runner/Idv::Proofer.document_job_class
DocumentCaptureSessionAsyncResult = Struct.new(:id, :status, :result, :pii, keyword_init: true) do
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

  alias_method :success?, :done?

  def in_progress?
    status == DocumentCaptureSessionAsyncResult::IN_PROGRESS
  end

  alias_method :pii_from_doc, :pii
end
