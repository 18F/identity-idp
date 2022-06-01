import sinon from 'sinon';
import SecretSessionStorage from './index';

describe('SecretSessionStorage', () => {
  const STORAGE_KEY = 'test';

  const sandbox = sinon.createSandbox();

  let key: CryptoKey;
  before(async () => {
    key = await window.crypto.subtle.generateKey(
      {
        name: 'AES-GCM',
        length: 256,
      },
      true,
      ['encrypt', 'decrypt'],
    );
  });

  function createStorage() {
    const storage = new SecretSessionStorage(STORAGE_KEY);
    storage.key = key;
    return storage;
  }

  afterEach(() => {
    sessionStorage.removeItem(STORAGE_KEY);
    sandbox.restore();
  });

  it('silently ignores invalid written storage', async () => {
    sessionStorage.setItem(STORAGE_KEY, 'nonsense');
    const storage = createStorage();
    await storage.load();
  });

  describe('#setItem', () => {
    it('writes to session storage', async () => {
      sandbox.spy(Storage.prototype, 'setItem');

      const storage = createStorage();
      await storage.setItem('foo', 'bar');

      expect(Storage.prototype.setItem).to.have.been.calledWith(
        STORAGE_KEY,
        sinon.match(
          (value: string) =>
            /^\[".+?",".+?"\]$/.test(value) && !value.includes('foo') && !value.includes('bar'),
        ),
      );
    });

    it('can recall stored data', async () => {
      const storage1 = createStorage();
      await storage1.setItem('foo', 'bar');
      const storage2 = createStorage();
      await storage2.load();

      expect(storage2.getItem('foo')).to.equal('bar');
    });
  });

  describe('#setItems', () => {
    it('writes to session storage', async () => {
      sandbox.spy(Storage.prototype, 'setItem');

      const storage = createStorage();
      await storage.setItems({ foo: 'bar' });

      expect(Storage.prototype.setItem).to.have.been.calledWith(
        STORAGE_KEY,
        sinon.match(
          (value: string) =>
            /^\[".+?",".+?"\]$/.test(value) && !value.includes('foo') && !value.includes('bar'),
        ),
      );
    });

    it('can recall stored data', async () => {
      const storage1 = createStorage();
      await storage1.setItems({ foo: 'bar' });
      const storage2 = createStorage();
      await storage2.load();

      expect(storage2.getItem('foo')).to.equal('bar');
    });
  });

  describe('#getItem', () => {
    it('returns the value from web storage', async () => {
      const storage1 = createStorage();
      await storage1.setItem('foo', 'bar');

      const storage2 = createStorage();
      await storage2.load();

      expect(storage2.getItem('foo')).to.equal('bar');
    });

    it('returns undefined for value not yet loaded from storage', async () => {
      const storage1 = createStorage();
      await storage1.setItem('foo', 'bar');

      const storage2 = createStorage();

      expect(storage2.getItem('foo')).to.be.undefined();
    });

    it('returns undefined for value not in loaded storage', async () => {
      const storage1 = createStorage();
      await storage1.setItem('foo', 'bar');

      const storage2 = createStorage();
      await storage2.load();

      expect(storage2.getItem('baz')).to.be.undefined();
    });
  });

  describe('#getItems', () => {
    it('returns the values from web storage', async () => {
      const storage1 = createStorage();
      await storage1.setItem('foo', 'bar');

      const storage2 = createStorage();
      await storage2.load();

      expect(storage2.getItems()).to.deep.equal({ foo: 'bar' });
    });

    it('returns empty object for value not yet loaded from storage', async () => {
      const storage1 = createStorage();
      await storage1.setItem('foo', 'bar');

      const storage2 = createStorage();

      expect(storage2.getItems()).to.deep.equal({});
    });
  });

  describe('#clear', () => {
    it('removes values from in-memory storage', async () => {
      const storage = createStorage();
      await storage.setItem('foo', 'bar');
      storage.clear();

      expect(storage.getItems()).to.deep.equal({});
    });

    it('removes values from persisted storage', async () => {
      const storage = createStorage();
      await storage.setItem('foo', 'bar');
      storage.clear();

      expect(sessionStorage.getItem(STORAGE_KEY)).be.null();
    });
  });
});
