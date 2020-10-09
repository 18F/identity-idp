class VerifyDocumentsStatusResponsePresenter
  def initialize(status_from_db)
    @status_from_db = status_from_db
  end

  def status
    status_from_db.nil? ? :bad_request : :ok
  end

  def success
    # only time this will fail is if status not found in the db. it starts as :in_progress
    status_from_db.present?
  end

  def to_h
    if success
      { success: true, status: status_from_db }
    else
      { success: false, status: status_from_db,
        errors: { document_capture_session_uuid: [I18n.t('doc_auth.errors.invalid_token')] } }
    end
  end

  def as_json(*)
    to_h
  end

  private

  attr_reader :status_from_db
end
