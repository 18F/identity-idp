# Read encrypted document artifacts

Add the encrypted storage reader and its local/S3 adapters with focused tests.

## Review boundary

Compare with `dcl/delegated-access/review-guide`. This dependency-ordered stack is reviewed and merged bottom-up. Foundation units can introduce code before endpoint wiring; request-level integration checks run on the completed stack, not every intermediate tree.

## Changelog

Add the encrypted storage reader and its local/S3 adapters with focused tests.

## Changed files

- `app/services/encrypted_doc_storage/doc_reader.rb`
- `app/services/encrypted_doc_storage/local_storage.rb`
- `app/services/encrypted_doc_storage/s3_storage.rb`
- `spec/services/encrypted_doc_storage/doc_reader_spec.rb`
- `spec/services/encrypted_doc_storage/local_storage_spec.rb`
- `spec/services/encrypted_doc_storage/s3_storage_spec.rb`

## Provenance and verification

Source commit: `4898d5f200`. Reconstructed on main `063d69fc915f073f5580f5105634d6215dbbb5bb`. See [verification](../verification.md) and the [merge manifest](../manifest.md).
