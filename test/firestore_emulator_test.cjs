const assert = require('node:assert/strict');

const projectId = process.env.FIREBASE_PROJECT_ID ?? 'demo-blocodenotasturmaa';
const authUrl = 'http://127.0.0.1:9099';
const firestoreUrl = 'http://127.0.0.1:8080';

async function createUser() {
  const response = await fetch(
    `${authUrl}/identitytoolkit.googleapis.com/v1/accounts:signUp?key=fake-api-key`,
    {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        email: `note-test-${Date.now()}-${Math.random().toString(36).slice(2)}@example.com`,
        password: 'test-password-123',
        returnSecureToken: true,
      }),
    },
  );
  const body = await response.json();
  assert.equal(response.status, 200, `Auth emulator: ${JSON.stringify(body)}`);
  return body;
}

async function main() {
  const owner = await createUser();
  const otherUser = await createUser();
  const noteId = `test-${Date.now()}`;
  const documentUrl =
    `${firestoreUrl}/v1/projects/${projectId}/databases/(default)/documents/` +
    `users/${owner.localId}/notes/${noteId}`;
  const ownerHeaders = {
    Authorization: `Bearer ${owner.idToken}`,
    'Content-Type': 'application/json',
  };
  const otherHeaders = { Authorization: `Bearer ${otherUser.idToken}` };

  const create = await fetch(documentUrl, {
    method: 'PATCH',
    headers: ownerHeaders,
    body: JSON.stringify({
      fields: {
        uid: { stringValue: owner.localId },
        title: { stringValue: 'Nota de integração' },
        content: { stringValue: 'Criada no Firestore Emulator' },
        category: { stringValue: 'Estudos' },
        date: { stringValue: '03/11/2026 20:00' },
        updatedAt: { integerValue: `${Date.now()}` },
      },
    }),
  });
  assert.equal(create.status, 200, `Create: ${await create.text()}`);

  const read = await fetch(documentUrl, { headers: ownerHeaders });
  const readDocument = await read.json();
  assert.equal(read.status, 200, `Read: ${JSON.stringify(readDocument)}`);
  assert.equal(readDocument.fields.title.stringValue, 'Nota de integração');
  assert.equal(readDocument.fields.category.stringValue, 'Estudos');

  const categoryUrl =
    `${firestoreUrl}/v1/projects/${projectId}/databases/(default)/documents/` +
    `users/${owner.localId}/categories/estudos`;
  const createCategory = await fetch(categoryUrl, {
    method: 'PATCH',
    headers: ownerHeaders,
    body: JSON.stringify({
      fields: {
        uid: { stringValue: owner.localId },
        name: { stringValue: 'Estudos' },
        updatedAt: { integerValue: `${Date.now()}` },
      },
    }),
  });
  assert.equal(createCategory.status, 200, `Create category: ${await createCategory.text()}`);

  const update = await fetch(`${documentUrl}?updateMask.fieldPaths=title`, {
    method: 'PATCH',
    headers: ownerHeaders,
    body: JSON.stringify({ fields: { title: { stringValue: 'Nota atualizada' } } }),
  });
  assert.equal(update.status, 200, `Update: ${await update.text()}`);

  const forbiddenRead = await fetch(documentUrl, { headers: otherHeaders });
  assert.equal(forbiddenRead.status, 403, 'A different user must not read the note');

  const forbiddenUpdate = await fetch(`${documentUrl}?updateMask.fieldPaths=title`, {
    method: 'PATCH',
    headers: otherHeaders,
    body: JSON.stringify({ fields: { title: { stringValue: 'Alteração indevida' } } }),
  });
  assert.equal(forbiddenUpdate.status, 403, 'A different user must not update the note');

  const forbiddenCategoryRead = await fetch(categoryUrl, { headers: otherHeaders });
  assert.equal(forbiddenCategoryRead.status, 403, 'A different user must not read categories');

  const remove = await fetch(documentUrl, { method: 'DELETE', headers: ownerHeaders });
  assert.equal(remove.status, 200, `Delete: ${await remove.text()}`);
  console.log('Firestore Emulator: create, read, update, delete and user isolation passed.');
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
