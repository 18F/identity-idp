# Release opted-in document images

Expose the document-image release path only under its feature and service-provider gates.

## Review boundary

Compare with `dcl/delegated-access/document-consent`. This dependency-ordered stack is reviewed and merged bottom-up. Foundation units can introduce code before endpoint wiring; request-level integration checks run on the completed stack, not every intermediate tree.

## Changelog

Expose the document-image release path only under its feature and service-provider gates.

## Changed files

- `app/controllers/openid_connect/document_images_controller.rb`
- `app/forms/openid_connect_authorize_form.rb`
- `app/presenters/openid_connect_user_info_presenter.rb`
- `app/services/analytics_events.rb`
- `app/services/openid_connect_attribute_scoper.rb`
- `config/routes.rb`
- `spec/controllers/openid_connect/document_images_controller_spec.rb`
- `spec/controllers/openid_connect/user_info_controller_spec.rb`
- `spec/forms/openid_connect_authorize_form_spec.rb`
- `spec/presenters/openid_connect_user_info_presenter_spec.rb`
- `spec/services/openid_connect_attribute_scoper_spec.rb`

## Provenance and verification

Source commit: `5f8641ee8c`. Reconstructed on main `063d69fc915f073f5580f5105634d6215dbbb5bb`. See [verification](../verification.md) and the [merge manifest](../manifest.md).
