# Capture verified document artifacts

Persist supported Socure verification artifacts with the owning profile and cleanup lifecycle.

## Review boundary

Compare with `dcl/delegated-access/document-artifacts`. This dependency-ordered stack is reviewed and merged bottom-up. Foundation units can introduce code before endpoint wiring; request-level integration checks run on the completed stack, not every intermediate tree.

## Changelog

Persist supported Socure verification artifacts with the owning profile and cleanup lifecycle.

## Changed files

- `app/jobs/socure_docv_results_job.rb`
- `app/jobs/socure_image_retrieval_job.rb`
- `app/services/idv/session.rb`
- `spec/jobs/socure_image_retrieval_job_spec.rb`
- `spec/services/idv/session_spec.rb`

## Provenance and verification

Source commit: `b4bcdb0e42`. Reconstructed on main `063d69fc915f073f5580f5105634d6215dbbb5bb`. See [verification](../verification.md) and the [merge manifest](../manifest.md).
