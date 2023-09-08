import { I18n } from '@18f/identity-i18n';
import { I18nContext } from '@18f/identity-react-i18n';
import UnknownError from '@18f/identity-document-capture/components/unknown-error';
import { toFormEntryError } from '@18f/identity-document-capture/services/upload';
import { within } from '@testing-library/dom';
import { render } from '../../../support/document-capture';

describe('UnknownError', () => {
  context('there is no doc type failure', () => {
    it('render an empty paragraph when no errors', () => {
      const { container } = render(
        <UnknownError unknownFieldErrors={[]} isFailedDocType={false} remainingAttempts={10} />,
      );
      expect(container.querySelector('p')).to.be.ok();
    });

    context('hasDismissed is true', () => {
      it('renders error message with errors and a help center link', () => {
        const { container } = render(
          <UnknownError
            unknownFieldErrors={[
              {
                field: 'general',
                error: toFormEntryError({ field: 'general', message: 'An unknown error occurred' }),
              },
            ]}
            isFailedDocType={false}
            remainingAttempts={10}
            hasDismissed
          />,
        );
        const paragraph = container.querySelector('p');
        expect(within(paragraph).getByText('An unknown error occurred')).to.be.ok();
        const link = container.querySelector('a');
        expect(link.text).to.eql('doc_auth.info.review_examples_of_photos');
      });
    });

    context('hasDismissed is false', () => {
      it('renders error message with errors but no link', () => {
        const { container, queryByRole } = render(
          <UnknownError
            unknownFieldErrors={[
              {
                field: 'general',
                error: toFormEntryError({ field: 'general', message: 'An unknown error occurred' }),
              },
            ]}
            isFailedDocType={false}
            remainingAttempts={10}
            hasDismissed={false}
          />,
        );

        const paragraph = container.querySelector('p');
        expect(within(paragraph).getByText('An unknown error occurred')).to.be.ok();
        expect(
          queryByRole('link', {
            name: 'doc_auth.info.review_examples_of_photos',
          }),
        ).to.not.exist();
      });
    });
  });

  context('there is a doc type failure', () => {
    it('renders error message with errors and is a doc type failure', () => {
      const { container } = render(
        <I18nContext.Provider
          value={
            new I18n({
              strings: {
                'idv.warning.attempts_html': {
                  one: 'You have <strong>One attempt</strong> remaining',
                  other: 'You have<strong>%{count} attempts</strong> remaining',
                },
                'errors.doc_auth.doc_type_not_supported_heading': 'doc type not supported',
              },
            })
          }
        >
          <UnknownError
            unknownFieldErrors={[
              {
                field: 'general',
                error: toFormEntryError({ field: 'general', message: 'An unknown error occurred' }),
              },
            ]}
            remainingAttempts={2}
            isFailedDocType
          />
        </I18nContext.Provider>,
      );
      const paragraph = container.querySelector('p');
      expect(within(paragraph).getByText(/An unknown error occurred/)).to.be.ok();
      expect(within(paragraph).getByText(/2 attempts/)).to.be.ok();
      expect(within(paragraph).getByText(/remaining/)).to.be.ok();
    });

    it('renders alternative error message with errors and is a doc type failure', () => {
      const { container } = render(
        <I18nContext.Provider
          value={
            new I18n({
              strings: {
                'idv.warning.attempts_html': {
                  one: 'You have <strong>One attempt</strong> remaining',
                  other: 'You have <strong>%{count} attempts</strong> remaining',
                },
              },
            })
          }
        >
          <UnknownError
            unknownFieldErrors={[
              {
                field: 'general',
                error: toFormEntryError({ field: 'general', message: 'An unknown error occurred' }),
              },
            ]}
            remainingAttempts={2}
            isFailedDocType
            altFailedDocTypeMsg="alternative message"
          />
        </I18nContext.Provider>,
      );
      const paragraph = container.querySelector('p');
      expect(within(paragraph).getByText(/alternative message/)).to.be.ok();
    });
  });
});
