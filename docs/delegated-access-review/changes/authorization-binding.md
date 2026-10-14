# Preserve compatibility while binding authorization transactions

Preserve ignored optional inputs and legacy Redis request shapes. Record the authorization binding decision before consent, then enforce saved bindings through code redemption and userinfo despite later flag changes.

## Review boundary

Compare with `dcl/delegated-access/consent-services`. This dependency-ordered stack is reviewed and merged bottom-up. Foundation units can introduce code before endpoint wiring; request-level integration checks run on the completed stack, not every intermediate tree.

## Changelog

Preserve ignored optional inputs and legacy Redis request shapes. Record the authorization binding decision before consent, then enforce saved bindings through code redemption and userinfo despite later flag changes.

## Changed files

- `app/controllers/openid_connect/authorization_controller.rb`
- `app/controllers/openid_connect/document_images_controller.rb`
- `app/controllers/openid_connect/token_controller.rb`
- `app/controllers/openid_connect/user_info_controller.rb`
- `app/decorators/service_provider_session.rb`
- `app/forms/openid_connect_authorize_form.rb`
- `app/forms/openid_connect_token_form.rb`
- `app/models/federated_protocols/oidc.rb`
- `app/models/federated_protocols/saml.rb`
- `app/models/service_provider_request.rb`
- `app/services/access_token_verifier.rb`
- `app/services/identity_linker.rb`
- `app/services/null_service_provider_request.rb`
- `app/services/openid_connect_attribute_scoper.rb`
- `app/services/service_provider_request_handler.rb`
- `app/services/service_provider_request_proxy.rb`
- `app/services/store_sp_metadata_in_session.rb`
- `spec/controllers/openid_connect/authorization_controller_spec.rb`
- `spec/forms/openid_connect_authorize_form_spec.rb`
- `spec/forms/openid_connect_token_form_spec.rb`
- `spec/requests/openid_connect_userinfo_spec.rb`
- `spec/services/access_token_verifier_spec.rb`
- `spec/services/identity_linker_spec.rb`
- `spec/services/openid_connect_attribute_scoper_spec.rb`
- `spec/services/service_provider_request_proxy_spec.rb`

## Provenance and verification

Source: original PRs #13632–#13645 through `3121f14fe1`. Reconstructed on main `063d69fc915f073f5580f5105634d6215dbbb5bb`. See [verification](../verification.md) and the [merge manifest](../manifest.md).
