import React from 'react';
import render from '../../../support/render';
import Accordion from '../../../../../app/javascript/app/document-capture/components/accordion';

describe('document-capture/components/accordion', () => {
  it('renders with a unique ID', () => {
    const { container } = render(
      <>
        <Accordion title="Title">Content</Accordion>
        <Accordion title="Title">Content</Accordion>
      </>,
    );

    const contents = container.querySelectorAll('[id^="accordion-content-"]');

    expect(contents).to.have.lengthOf(2);
    expect(contents[0].id).to.be.ok();
    expect(contents[1].id).to.be.ok();
    expect(contents[0].id).not.to.equal(contents[1].id);
  });
});
