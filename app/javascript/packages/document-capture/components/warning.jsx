import PageHeading from './page-heading';

/* <h1 class="margin-top-4 margin-bottom-2"><%= heading %></h1>

<%= yield %>

<% if local_assigns[:action] %>
  <div class="margin-top-4">
    <%= button_or_link_to(
          action[:text],
          action[:url],
          class: 'usa-button usa-button--big usa-button--wide',
          method: action[:method],
        ) %>
  </div>

  <% if local_assigns[:action_secondary] %>
    <div class="margin-top-2">
      <%= button_or_link_to(
            action_secondary[:text],
            action_secondary[:url],
            class: 'usa-button usa-button--big usa-button--wide usa-button--outline',
            method: action_secondary[:method],
          ) %>
    </div>
  <% end %>
<% end %>

<%= render(
      'shared/troubleshooting_options',
      heading: troubleshooting_heading,
      options: local_assigns.fetch(:options, []),
      class: 'margin-top-5',
    ) %> */

import { useEffect, useRef } from 'react';
import useAsset from '../hooks/use-asset';

// todo: move me to components

function Warning({ heading, actionText, actionOnClick, children, autoFocus }) {
  const { getAssetPath } = useAsset();
  const headingRef = useRef(/** @type {HTMLHeadingElement?} */ (null));
  useEffect(() => {
    if (autoFocus) {
      headingRef.current?.focus();
    }
  }, []);

  return (
    <>
      <img
        alt=""
        src={getAssetPath('alert/warning-lg.svg')}
        width={54}
        height={54}
        className="display-block"
      />
      <PageHeading ref={headingRef} tabIndex={-1}>
        {heading}
      </PageHeading>
      {children}
      {actionText && actionOnClick && (
        <div className="margin-top-2">
          <button
            type="button"
            className="usa-button usa-button--big usa-button--wide"
            onClick={actionOnClick}
          >
            {actionText}
          </button>
        </div>
      )}
    </>
  );
}

export default Warning;
