import FormError from './form-error';

describe('FormError', () => {
  it('constructs with a message', () => {
    const error = new FormError('message');

    expect(error.message).to.equal('message');
    expect(error.isDetail).to.be.false();
    expect(error.field).to.be.undefined();
  });

  it('constructs as detailed error', () => {
    const error = new FormError('message', { isDetail: true });

    expect(error.message).to.equal('message');
    expect(error.isDetail).to.be.true();
    expect(error.field).to.be.undefined();
  });

  it('constructs as associated with a field', () => {
    const error = new FormError('message', { field: 'field' });

    expect(error.message).to.equal('message');
    expect(error.isDetail).to.be.false();
    expect(error.field).to.equal('field');
  });

  it('supports message on subclass property initializer', () => {
    class ExampleFormError extends FormError {
      message = 'message';
    }

    const error = new ExampleFormError();

    expect(error.message).to.equal('message');
    expect(error.isDetail).to.be.false();
    expect(error.field).to.be.undefined();
  });
});
