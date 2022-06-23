import { render } from '@testing-library/react';
import Button from './button';
import StatusPage from './status-page';
import TroubleshootingOptions from './troubleshooting-options';

describe('StatusPage', () => {
  it('renders heading and content for status', () => {
    const { getByRole, getByText } = render(
      <StatusPage status="error" header="Header">
        <div>Content</div>
      </StatusPage>,
    );

    const icon = getByRole('img');
    const heading = getByRole('heading');
    const content = getByText('Content');

    expect(icon.getAttribute('src')).to.equal('status/error.svg');
    expect(icon.getAttribute('alt')).to.equal('components.status_page.icons.error');
    expect(content).to.exist();
    expect(heading.textContent).to.equal('Header');
    expect(icon.compareDocumentPosition(heading)).to.equal(Node.DOCUMENT_POSITION_FOLLOWING);
    expect(heading.compareDocumentPosition(content)).to.equal(Node.DOCUMENT_POSITION_FOLLOWING);
  });

  context('with icon variation', () => {
    it('renders icon variation', () => {
      const { getByRole } = render(<StatusPage status="info" icon="question" header="" />);

      const icon = getByRole('img');

      expect(icon.getAttribute('src')).to.equal('status/info-question.svg');
      expect(icon.getAttribute('alt')).to.equal('components.status_page.icons.question');
    });
  });

  context('with action buttons', () => {
    it('renders buttons below content', () => {
      const { getByRole, getByText } = render(
        <StatusPage status="warning" header="" actionButtons={[<Button>Button</Button>]}>
          <div>Content</div>
        </StatusPage>,
      );

      const content = getByText('Content');
      const button = getByRole('button');

      expect(content.compareDocumentPosition(button)).to.equal(Node.DOCUMENT_POSITION_FOLLOWING);
    });
  });

  context('with troubleshooting options', () => {
    it('renders troubleshooting options below buttons', () => {
      const { getByRole } = render(
        <StatusPage
          status="warning"
          header=""
          actionButtons={[<Button>Button</Button>]}
          troubleshootingOptions={
            <TroubleshootingOptions options={[{ url: '/', text: 'Option' }]} />
          }
        >
          <div>Content</div>
        </StatusPage>,
      );

      const button = getByRole('button');
      const options = getByRole('list');

      expect(button.compareDocumentPosition(options)).to.equal(Node.DOCUMENT_POSITION_FOLLOWING);
    });
  });
});
