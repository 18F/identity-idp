module Idv
  module DocumentCaptureConcern
    extend ActiveSupport::Concern

    def save_proofing_components
        return unless effective_user
  
        doc_auth_vendor = DocAuthRouter.doc_auth_vendor(
          discriminator: document_capture_session_uuid,
          analytics: analytics,
        )
  
        component_attributes = {
          document_check: doc_auth_vendor,
          document_type: 'state_id',
        }
        ProofingComponent.create_or_find_by(user: effective_user).update(component_attributes)
      end
  end
end
