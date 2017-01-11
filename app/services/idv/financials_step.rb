module Idv
  class FinancialsStep < Step
    def complete?
      idv_form.finance_type && idv_session.financials_confirmation.try(:success?) ? true : false
    end

    private

    def confirm
      session_id = idv_session.resolution.session_id
      idv_session.financials_confirmation = idv_agent.submit_financials(financials, session_id)
      idv_session.params = idv_form.idv_params if complete?
      idv_session.financials_confirmation.success?
    end

    def track_event
      result = { success: complete?, errors: errors }

      analytics.track_event(Analytics::IDV_FINANCE_CONFIRMATION, result)
    end

    def vendor_errors
      idv_session.financials_confirmation.try(:errors)
    end

    def financials
      finance_type = idv_form.finance_type
      { finance_type => idv_form.idv_params[finance_type] }
    end
  end
end
