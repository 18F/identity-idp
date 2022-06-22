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
  self::MISSING = 'missing'

  def self.redis_key_prefix
    'dcs-async:result'
  end

  def self.missing
    new(status: DocumentCaptureSessionAsyncResult::MISSING)
  end

  def missing?
    status == DocumentCaptureSessionAsyncResult::MISSING
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

  def attention_with_barcode?
    done? && result[:attention_with_barcode]
  end

  alias_method :pii_from_doc, :pii
end
