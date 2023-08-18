import { render, screen, within } from '@testing-library/react';
import { InPersonContext } from '@18f/identity-document-capture/context';
import { toFormEntryError } from '@18f/identity-document-capture/services/upload';
import { expect } from 'chai';
import DocumentCaptureWarning from '@18f/identity-document-capture/components/document-capture-warning';

describe('DocumentCaptureWarning', () => {
  context('ipp ', () => {
    context('not failed result', () => {
      const isFailedResult = false;
      it('renders with failed doc type', () => {
        const isFailedDocType = false;
        const unknownFieldErrors = [
          {
            field: 'general',
            error: toFormEntryError({ field: 'general', message: 'general error' }),
          },
        ];
        const { getByRole, getByText } = render(
          <InPersonContext.Provider value={{ inPersonURL: '/verify/doc_capture' }}>
            <DocumentCaptureWarning
              isFailedDocType={isFailedDocType}
              isFailedResult={isFailedResult}
              remainingAttempts={2}
              unknownFieldErrors={unknownFieldErrors}
              actionOnClick={() => {}}
            />
            ,
          </InPersonContext.Provider>,
        );

        // error message section
        const h1 = screen.getByRole('heading', {
          name: 'errors.doc_auth.rate_limited_heading',
          level: 1,
        });
        expect(h1).to.be.ok();

        const h2 = screen.getByRole('heading', {
          name: 'errors.doc_auth.rate_limited_subheading',
          level: 2,
        });
        expect(h2).to.be.ok();

        expect(getByText('general error')).to.be.ok();
        expect(getByText('idv.failure.attempts_html')).to.be.ok();
        expect(getByRole('button', { name: 'idv.failure.button.try_online' })).to.be.ok();

        // ipp section
        expect(
          screen.getByRole('heading', {
            name: 'in_person_proofing.headings.cta',
            level: 2,
          }),
        ).to.be.ok();
        /* ipp prompt */
        expect(getByText('in_person_proofing.body.cta.prompt_detail')).to.be.ok();
        expect(getByRole('button', { name: 'in_person_proofing.body.cta.button' })).to.be.ok();

        // troubleshooting section
        expect(
          screen.getByRole('heading', {
            name: 'components.troubleshooting_options.ipp_heading',
            level: 2,
          }),
        ).to.be.ok();
        /* list of troubleshooting links */
        const troubleShootingList = getByRole('list');
        expect(troubleShootingList).to.be.ok();

        const troubleShootingListItem = within(troubleShootingList).getAllByRole('listitem');
        expect(troubleShootingListItem).to.be.ok();
        const hrefLinks = within(troubleShootingList).getAllByRole('link');

        hrefLinks.forEach((hrefLink) => {
          expect(hrefLink.href).to.contains('location=post_submission_warning');
          expect(hrefLink.href).to.contains('article=');
        });
      });

      it('renders with failed doc type', () => {
        const isFailedDocType = true;
        const unknownFieldErrors = [
          {
            field: 'general',
            error: toFormEntryError({ field: 'general', message: 'general error' }),
          },
        ];
        const { getByRole, getByText } = render(
          <InPersonContext.Provider value={{ inPersonURL: '/verify/doc_capture' }}>
            <DocumentCaptureWarning
              isFailedDocType={isFailedDocType}
              isFailedResult={isFailedResult}
              remainingAttempts={2}
              unknownFieldErrors={unknownFieldErrors}
              actionOnClick={() => {}}
            />
            ,
          </InPersonContext.Provider>,
        );

        // error message section
        const h1 = screen.getByRole('heading', {
          name: 'errors.doc_auth.doc_type_not_supported_heading',
          level: 1,
        });
        expect(h1).to.be.ok();

        const h2 = screen.queryByRole('heading', {
          name: 'errors.doc_auth.rate_limited_subheading',
          level: 2,
        });
        expect(h2).to.be.null();

        expect(getByText(/general error/)).to.be.ok();
        expect(getByText(/idv.warning.attempts_html/)).to.be.ok();
        expect(getByRole('button', { name: 'idv.failure.button.try_online' })).to.be.ok();

        // ipp section
        expect(
          screen.getByRole('heading', {
            name: 'in_person_proofing.headings.cta',
            level: 2,
          }),
        ).to.be.ok();
        /* ipp prompt */
        expect(getByText('in_person_proofing.body.cta.prompt_detail')).to.be.ok();
        expect(getByRole('button', { name: 'in_person_proofing.body.cta.button' })).to.be.ok();

        // troubleshooting section
        expect(
          screen.getByRole('heading', {
            name: 'components.troubleshooting_options.ipp_heading',
            level: 2,
          }),
        ).to.be.ok();
        /* list of troubleshooting links */
        const troubleShootingList = getByRole('list');
        expect(troubleShootingList).to.be.ok();

        const troubleShootingListItem = within(troubleShootingList).getAllByRole('listitem');
        expect(troubleShootingListItem).to.be.ok();
        const hrefLinks = within(troubleShootingList).getAllByRole('link');

        hrefLinks.forEach((hrefLink) => {
          expect(hrefLink.href).to.contains('location=post_submission_warning');
          expect(hrefLink.href).to.contains('article=');
        });
      });
    });

    context('failed result', () => {
      const isFailedResult = true;
      it('renders not failed doc type', () => {
        const isFailedDocType = false;
        const unknownFieldErrors = [
          {
            field: 'general',
            error: toFormEntryError({ field: 'general', message: 'general error' }),
          },
        ];
        const { getByRole, getByText } = render(
          <InPersonContext.Provider value={{ inPersonURL: '/verify/doc_capture' }}>
            <DocumentCaptureWarning
              isFailedDocType={isFailedDocType}
              isFailedResult={isFailedResult}
              remainingAttempts={2}
              unknownFieldErrors={unknownFieldErrors}
              actionOnClick={() => {}}
            />
            ,
          </InPersonContext.Provider>,
        );

        // error message section
        const h1 = screen.getByRole('heading', {
          name: 'errors.doc_auth.rate_limited_heading',
          level: 1,
        });
        expect(h1).to.be.ok();

        const h2 = screen.queryByRole('heading', {
          name: 'errors.doc_auth.rate_limited_subheading',
          level: 2,
        });
        expect(h2).to.be.null();

        expect(getByText('general error')).to.be.ok();
        expect(getByText('idv.failure.attempts_html')).to.be.ok();
        expect(getByRole('button', { name: 'idv.failure.button.warning' })).to.be.ok();

        // the ipp section is not displayed with isFailedResult=true
        expect(
          screen.queryByRole('heading', {
            name: 'in_person_proofing.headings.cta',
            level: 2,
          }),
        ).to.be.null();
        expect(screen.queryByText('in_person_proofing.body.cta.prompt_detail')).to.be.null();
        expect(
          screen.queryByRole('button', { name: 'in_person_proofing.body.cta.button' }),
        ).to.be.null();

        // troubleshooting section
        expect(
          screen.getByRole('heading', {
            name: 'components.troubleshooting_options.ipp_heading',
            level: 2,
          }),
        ).to.be.ok();
        /* list of troubleshooting links */
        const troubleShootingList = getByRole('list');
        expect(troubleShootingList).to.be.ok();

        const troubleShootingListItem = within(troubleShootingList).getAllByRole('listitem');
        expect(troubleShootingListItem).to.be.ok();
        const hrefLinks = within(troubleShootingList).getAllByRole('link');

        hrefLinks.forEach((hrefLink) => {
          expect(hrefLink.href).to.contains('location=post_submission_warning');
          expect(hrefLink.href).to.contains('article=');
        });
      });

      it('renders with failed doc type', () => {
        const isFailedDocType = true;
        const unknownFieldErrors = [
          {
            field: 'general',
            error: toFormEntryError({ field: 'general', message: 'general error' }),
          },
        ];
        const { getByRole, getByText } = render(
          <InPersonContext.Provider value={{ inPersonURL: '/verify/doc_capture' }}>
            <DocumentCaptureWarning
              isFailedDocType={isFailedDocType}
              isFailedResult={isFailedResult}
              remainingAttempts={2}
              unknownFieldErrors={unknownFieldErrors}
              actionOnClick={() => {}}
            />
            ,
          </InPersonContext.Provider>,
        );

        // error message section
        const h1 = screen.getByRole('heading', {
          name: 'errors.doc_auth.doc_type_not_supported_heading',
          level: 1,
        });
        expect(h1).to.be.ok();

        const h2 = screen.queryByRole('heading', {
          name: 'errors.doc_auth.rate_limited_subheading',
          level: 2,
        });
        expect(h2).to.be.null();

        expect(getByText(/general error/)).to.be.ok();
        expect(getByText(/idv.warning.attempts_html/)).to.be.ok();
        expect(getByRole('button', { name: 'idv.failure.button.warning' })).to.be.ok();

        // ipp section not existing
        expect(
          screen.queryByRole('heading', {
            name: 'in_person_proofing.headings.cta',
            level: 2,
          }),
        ).to.be.null();

        expect(screen.queryByText('in_person_proofing.body.cta.prompt_detail')).to.be.null();
        expect(
          screen.queryByRole('button', { name: 'in_person_proofing.body.cta.button' }),
        ).to.be.null();

        // troubleshooting section
        expect(
          screen.getByRole('heading', {
            name: 'components.troubleshooting_options.ipp_heading',
            level: 2,
          }),
        ).to.be.ok();
        /* list of troubleshooting links */
        const troubleShootingList = getByRole('list');
        expect(troubleShootingList).to.be.ok();

        const troubleShootingListItem = within(troubleShootingList).getAllByRole('listitem');
        expect(troubleShootingListItem).to.be.ok();
        const hrefLinks = within(troubleShootingList).getAllByRole('link');

        hrefLinks.forEach((hrefLink) => {
          expect(hrefLink.href).to.contains('location=post_submission_warning');
          expect(hrefLink.href).to.contains('article=');
        });
      });
    });
  });

  context('non ipp ', () => {
    context('not failed result', () => {
      const isFailedResult = false;
      it('renders with failed doc type', () => {
        const isFailedDocType = false;
        const unknownFieldErrors = [
          {
            field: 'general',
            error: toFormEntryError({ field: 'general', message: 'general error' }),
          },
        ];
        const { getByRole, getByText } = render(
          <InPersonContext.Provider value={{ inPersonURL: '' }}>
            <DocumentCaptureWarning
              isFailedDocType={isFailedDocType}
              isFailedResult={isFailedResult}
              remainingAttempts={2}
              unknownFieldErrors={unknownFieldErrors}
              actionOnClick={() => {}}
            />
            ,
          </InPersonContext.Provider>,
        );

        // error message section
        const h1 = screen.getByRole('heading', {
          name: 'errors.doc_auth.rate_limited_heading',
          level: 1,
        });
        expect(h1).to.be.ok();

        const h2 = screen.queryByRole('heading', {
          name: 'errors.doc_auth.rate_limited_subheading',
          level: 2,
        });
        expect(h2).to.be.null();

        expect(getByText('general error')).to.be.ok();
        expect(getByText('idv.failure.attempts_html')).to.be.ok();
        expect(getByRole('button', { name: 'idv.failure.button.warning' })).to.be.ok();

        // ipp section not displayed for non ipp
        expect(
          screen.queryByRole('heading', {
            name: 'in_person_proofing.headings.cta',
            level: 2,
          }),
        ).to.be.null();
        /* ipp prompt */
        expect(screen.queryByText('in_person_proofing.body.cta.prompt_detail')).to.be.null();
        expect(
          screen.queryByRole('button', { name: 'in_person_proofing.body.cta.button' }),
        ).to.be.null();

        // troubleshooting section
        expect(
          screen.getByRole('heading', {
            name: 'components.troubleshooting_options.ipp_heading',
            level: 2,
          }),
        ).to.be.ok();
        /* list of troubleshooting links */
        const troubleShootingList = getByRole('list');
        expect(troubleShootingList).to.be.ok();

        const troubleShootingListItem = within(troubleShootingList).getAllByRole('listitem');
        expect(troubleShootingListItem).to.be.ok();
        const hrefLinks = within(troubleShootingList).getAllByRole('link');

        hrefLinks.forEach((hrefLink) => {
          expect(hrefLink.href).to.contains('location=post_submission_warning');
          expect(hrefLink.href).to.contains('article=');
        });
      });

      it('renders with failed doc type', () => {
        const isFailedDocType = true;
        const unknownFieldErrors = [
          {
            field: 'general',
            error: toFormEntryError({ field: 'general', message: 'general error' }),
          },
        ];
        const { getByRole, getByText } = render(
          <InPersonContext.Provider value={{ inPersonURL: '' }}>
            <DocumentCaptureWarning
              isFailedDocType={isFailedDocType}
              isFailedResult={isFailedResult}
              remainingAttempts={2}
              unknownFieldErrors={unknownFieldErrors}
              actionOnClick={() => {}}
            />
            ,
          </InPersonContext.Provider>,
        );

        // error message section
        const h1 = screen.getByRole('heading', {
          name: 'errors.doc_auth.doc_type_not_supported_heading',
          level: 1,
        });
        expect(h1).to.be.ok();

        const h2 = screen.queryByRole('heading', {
          name: 'errors.doc_auth.rate_limited_subheading',
          level: 2,
        });
        expect(h2).to.be.null();

        expect(getByText(/general error/)).to.be.ok();
        expect(getByText(/idv.warning.attempts_html/)).to.be.ok();
        expect(getByRole('button', { name: 'idv.failure.button.warning' })).to.be.ok();

        // ipp section not displayed for non ipp
        expect(
          screen.queryByRole('heading', {
            name: 'in_person_proofing.headings.cta',
            level: 2,
          }),
        ).to.be.null();
        /* ipp prompt */
        expect(screen.queryByText('in_person_proofing.body.cta.prompt_detail')).to.be.null();
        expect(
          screen.queryByRole('button', { name: 'in_person_proofing.body.cta.button' }),
        ).to.be.null();

        // troubleshooting section
        expect(
          screen.getByRole('heading', {
            name: 'components.troubleshooting_options.ipp_heading',
            level: 2,
          }),
        ).to.be.ok();
        /* list of troubleshooting links */
        const troubleShootingList = getByRole('list');
        expect(troubleShootingList).to.be.ok();

        const troubleShootingListItem = within(troubleShootingList).getAllByRole('listitem');
        expect(troubleShootingListItem).to.be.ok();
        const hrefLinks = within(troubleShootingList).getAllByRole('link');

        hrefLinks.forEach((hrefLink) => {
          expect(hrefLink.href).to.contains('location=post_submission_warning');
          expect(hrefLink.href).to.contains('article=');
        });
      });
    });

    //
    context('failed result', () => {
      const isFailedResult = true;
      it('renders not failed doc type', () => {
        const isFailedDocType = false;
        const unknownFieldErrors = [
          {
            field: 'general',
            error: toFormEntryError({ field: 'general', message: 'general error' }),
          },
        ];
        const { getByRole, getByText } = render(
          <InPersonContext.Provider value={{ inPersonURL: '/verify/doc_capture' }}>
            <DocumentCaptureWarning
              isFailedDocType={isFailedDocType}
              isFailedResult={isFailedResult}
              remainingAttempts={2}
              unknownFieldErrors={unknownFieldErrors}
              actionOnClick={() => {}}
            />
            ,
          </InPersonContext.Provider>,
        );

        // error message section
        const h1 = screen.getByRole('heading', {
          name: 'errors.doc_auth.rate_limited_heading',
          level: 1,
        });
        expect(h1).to.be.ok();

        const h2 = screen.queryByRole('heading', {
          name: 'errors.doc_auth.rate_limited_subheading',
          level: 2,
        });
        expect(h2).to.be.null();

        expect(getByText('general error')).to.be.ok();
        expect(getByText('idv.failure.attempts_html')).to.be.ok();
        expect(getByRole('button', { name: 'idv.failure.button.warning' })).to.be.ok();

        // the ipp section is not displayed with isFailedResult=true
        expect(
          screen.queryByRole('heading', {
            name: 'in_person_proofing.headings.cta',
            level: 2,
          }),
        ).to.be.null();
        expect(screen.queryByText('in_person_proofing.body.cta.prompt_detail')).to.be.null();
        expect(
          screen.queryByRole('button', { name: 'in_person_proofing.body.cta.button' }),
        ).to.be.null();

        // troubleshooting section
        expect(
          screen.getByRole('heading', {
            name: 'components.troubleshooting_options.ipp_heading',
            level: 2,
          }),
        ).to.be.ok();
        /* list of troubleshooting links */
        const troubleShootingList = getByRole('list');
        expect(troubleShootingList).to.be.ok();

        const troubleShootingListItem = within(troubleShootingList).getAllByRole('listitem');
        expect(troubleShootingListItem).to.be.ok();
        const hrefLinks = within(troubleShootingList).getAllByRole('link');

        hrefLinks.forEach((hrefLink) => {
          expect(hrefLink.href).to.contains('location=post_submission_warning');
          expect(hrefLink.href).to.contains('article=');
        });
      });

      it('renders with failed doc type', () => {
        const isFailedDocType = true;
        const unknownFieldErrors = [
          {
            field: 'general',
            error: toFormEntryError({ field: 'general', message: 'general error' }),
          },
        ];
        const { getByRole, getByText } = render(
          <InPersonContext.Provider value={{ inPersonURL: '/verify/doc_capture' }}>
            <DocumentCaptureWarning
              isFailedDocType={isFailedDocType}
              isFailedResult={isFailedResult}
              remainingAttempts={2}
              unknownFieldErrors={unknownFieldErrors}
              actionOnClick={() => {}}
            />
            ,
          </InPersonContext.Provider>,
        );

        // error message section
        const h1 = screen.getByRole('heading', {
          name: 'errors.doc_auth.doc_type_not_supported_heading',
          level: 1,
        });
        expect(h1).to.be.ok();

        const h2 = screen.queryByRole('heading', {
          name: 'errors.doc_auth.rate_limited_subheading',
          level: 2,
        });
        expect(h2).to.be.null();

        expect(getByText(/general error/)).to.be.ok();
        expect(getByText(/idv.warning.attempts_html/)).to.be.ok();
        expect(getByRole('button', { name: 'idv.failure.button.warning' })).to.be.ok();

        // ipp section not existing
        expect(
          screen.queryByRole('heading', {
            name: 'in_person_proofing.headings.cta',
            level: 2,
          }),
        ).to.be.null();

        expect(screen.queryByText('in_person_proofing.body.cta.prompt_detail')).to.be.null();
        expect(
          screen.queryByRole('button', { name: 'in_person_proofing.body.cta.button' }),
        ).to.be.null();

        // troubleshooting section
        expect(
          screen.getByRole('heading', {
            name: 'components.troubleshooting_options.ipp_heading',
            level: 2,
          }),
        ).to.be.ok();
        /* list of troubleshooting links */
        const troubleShootingList = getByRole('list');
        expect(troubleShootingList).to.be.ok();

        const troubleShootingListItem = within(troubleShootingList).getAllByRole('listitem');
        expect(troubleShootingListItem).to.be.ok();
        const hrefLinks = within(troubleShootingList).getAllByRole('link');

        hrefLinks.forEach((hrefLink) => {
          expect(hrefLink.href).to.contains('location=post_submission_warning');
          expect(hrefLink.href).to.contains('article=');
        });
      });
    });
  });
});
