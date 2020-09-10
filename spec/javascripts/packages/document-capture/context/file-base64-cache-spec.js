import { createElement, useContext } from 'react';
import FileBase64Cache from '@18f/identity-document-capture/context/file-base64-cache';
import render from '../../../support/render';

describe('document-capture/context/file-base64-cache', () => {
  it('defaults to WeakMap', () => {
    render(
      createElement(() => {
        const cache = useContext(FileBase64Cache);
        expect(cache).to.be.instanceof(WeakMap);
        return null;
      }),
    );
  });
});
