# frozen_string_literal: true

module NDS
  # View helper that renders the NDS account-creation header progress stepper.
  # Available to all views; not yet called by any page. A consuming page opts
  # in by setting content_for(:nds_header_progress) with this helper's output.
  module AccountCreationProgressHelper
    def nds_account_creation_progress(step:, substep: nil)
      render NDS::ProgressComponent.new(
        **NDS::AccountCreationSteps.progress_args(step:, substep:),
      )
    end
  end
end
