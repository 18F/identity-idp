import GeneralError from '@18f/identity-document-capture/components/general-error';
import { toFormEntryError } from '@18f/identity-document-capture/services/upload';
import { within } from '@testing-library/dom';
import { render } from '../../../support/document-capture';

describe('GeneralError', () => {
  context('there is no doc type failure', () => {
    it('render an empty paragraph when no errors', () => {
      const { container } = render(<GeneralError unknownFieldErrors={[]} isFailedDocType={false} />);
      expect(container.querySelector('p')).to.be.ok();
    });

    context('hasDismissed is true', () => {
      it('renders error message with errors and a help center link', () => {
        const { container } = render(
          <GeneralError
            unknownFieldErrors={[
              {
                field: 'general',
                error: toFormEntryError({ field: 'general', message: 'An unknown error occurred' }),
              },
            ]}
            isFailedDocType={false}
            hasDismissed
          />,
        );
        const paragraph = container.querySelector('p');
        expect(within(paragraph).getByText('An unknown error occurred')).to.be.ok();
        const link = container.querySelector('a');
        expect(link.text).to.eql('doc_auth.info.review_examples_of_photoslinks.new_tab');
      });
    });

    context('hasDismissed is false', () => {
      it('renders error message with errors but no link', () => {
        const { container, queryByRole } = render(
          <GeneralError
            unknownFieldErrors={[
              {
                field: 'general',
                error: toFormEntryError({ field: 'general', message: 'An unknown error occurred' }),
              },
            ]}
            isFailedDocType={false}
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
        <GeneralError
          unknownFieldErrors={[
            {
              field: 'general',
              error: toFormEntryError({ field: 'general', message: 'An unknown error occurred' }),
            },
          ]}
          isFailedDocType
        />,
      );
      const paragraph = container.querySelector('p');
      expect(within(paragraph).getByText(/An unknown error occurred/)).to.be.ok();
    });

    it('renders alternative error message with errors and is a doc type failure', () => {
      const { container } = render(
        <GeneralError
          unknownFieldErrors={[
            {
              field: 'general',
              error: toFormEntryError({ field: 'general', message: 'An unknown error occurred' }),
            },
          ]}
          isFailedDocType
          altFailedDocTypeMsg="alternative message"
        />,
      );
      const paragraph = container.querySelector('p');
      expect(within(paragraph).getByText(/alternative message/)).to.be.ok();
    });
  });

  context('there is a selfie quality/liveness failure', () => {
    it('renders error message with errors', () => {
      const { container } = render(
        <GeneralError
          unknownFieldErrors={[
            {
              field: 'general',
              error: toFormEntryError({ field: 'general', message: 'An unknown error occurred' }),
            },
          ]}
          isFailedSelfieLivenessOrQuality
        />,
      );
      expect(within(container).getByText(/An unknown error occurred/)).to.be.ok();
    });

    it('renders alternative error message without retry information', () => {
      const { container } = render(
        <GeneralError
          unknownFieldErrors={[
            {
              field: 'general',
              error: toFormEntryError({ field: 'general', message: 'An unknown error occurred' }),
            },
          ]}
          isFailedSelfieLivenessOrQuality
          altIsFailedSelfieDontIncludeAttempts
        />,
      );
      expect(within(container).getByText(/An unknown error occurred/)).to.be.ok();
    });
  });

  context('there is a selfie facematch failure', () => {
    it('renders error message with errors', () => {
      const { container } = render(
        <GeneralError
          unknownFieldErrors={[
            {
              field: 'general',
              error: toFormEntryError({ field: 'general', message: 'An unknown error occurred' }),
            },
          ]}
          isFailedSelfie
        />,
      );
      expect(within(container).getByText(/An unknown error occurred/)).to.be.ok();
    });

    it('renders alternative error message without retry information', () => {
      const { container } = render(
        <GeneralError
          unknownFieldErrors={[
            {
              field: 'general',
              error: toFormEntryError({ field: 'general', message: 'An unknown error occurred' }),
            },
          ]}
          isFailedSelfie
          altIsFailedSelfieDontIncludeAttempts
        />,
      );
      expect(within(container).getByText(/An unknown error occurred/)).to.be.ok();
    });
  });
});
