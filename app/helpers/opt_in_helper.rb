# frozen_string_literal: true

module OptInHelper
  def opt_in_analytics_properties
    if IdentityConfig.store.in_person_proofing_opt_in_enabled
      {
        opted_in_to_in_person_proofing: idv_session.opted_in_to_in_person_proofing,
        doc_auth_result: idv_session.doc_auth_result,
      }
      else
        {}
      end
  end
end
