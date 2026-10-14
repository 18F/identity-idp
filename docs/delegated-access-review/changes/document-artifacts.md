# Model shareable document artifacts

Add the narrow document-artifact and metadata records, profile relationships, expiry cleanup, and migrations.

## Review boundary

Compare with `dcl/delegated-access/document-storage`. This dependency-ordered stack is reviewed and merged bottom-up. Foundation units can introduce code before endpoint wiring; request-level integration checks run on the completed stack, not every intermediate tree.

## Changelog

Add the narrow document-artifact and metadata records, profile relationships, expiry cleanup, and migrations.

## Changed files

- `app/jobs/expire_document_artifacts_job.rb`
- `app/models/document_artifact.rb`
- `app/models/document_capture_session.rb`
- `app/models/document_metadata.rb`
- `app/models/profile.rb`
- `app/models/service_provider.rb`
- `app/models/service_provider_identity.rb`
- `app/services/analytics_events.rb`
- `config/application.yml.default`
- `config/initializers/job_configurations.rb`
- `db/primary_migrate/20260924100000_create_document_artifacts.rb`
- `db/primary_migrate/20260924100100_add_biometric_sharing_consent_at_to_identities.rb`
- `db/primary_migrate/20260924100200_add_unique_index_to_document_artifacts.rb`
- `db/primary_migrate/20260924100300_add_profile_id_to_document_capture_sessions.rb`
- `db/primary_migrate/20260924100400_validate_profile_foreign_key_on_document_capture_sessions.rb`
- `db/primary_migrate/20260924100500_create_document_metadata.rb`
- `db/schema.rb`
- `lib/identity_config.rb`
- `spec/factories/document_artifacts.rb`
- `spec/factories/document_metadata.rb`
- `spec/jobs/expire_document_artifacts_job_spec.rb`
- `spec/models/document_artifact_spec.rb`
- `spec/models/document_metadata_spec.rb`
- `spec/models/profile_spec.rb`
- `spec/models/service_provider_identity_spec.rb`
- `spec/models/service_provider_spec.rb`

## Provenance and verification

Source commit: `0619fd1540`. Reconstructed on main `063d69fc915f073f5580f5105634d6215dbbb5bb`. See [verification](../verification.md) and the [merge manifest](../manifest.md).
