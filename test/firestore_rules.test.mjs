import {readFile} from 'node:fs/promises';
import {after, before, beforeEach, test} from 'node:test';
import {initializeTestEnvironment, assertFails, assertSucceeds} from '@firebase/rules-unit-testing';
import {doc, collection, setDoc, getDoc, getDocs, updateDoc, deleteDoc, serverTimestamp, deleteField} from 'firebase/firestore';

let env;
const id = '00000000-0000-4000-8000-000000000001';
const payload = () => ({uid: 'alice', title: 'Estudar', content: 'Revisar a prova',
  category: 'Estudos', archived: false, deleted: false, updatedAt: Date.now(), reminderAt: null,
  revision: id, syncedAt: serverTimestamp()});
const ref = (db, uid = 'alice') => doc(db, `users/${uid}/notes/${id}`);
before(async () => {
  env = await initializeTestEnvironment({projectId: 'demo-bloco-notas', firestore: {
    rules: await readFile(new URL('../firestore.rules', import.meta.url), 'utf8')}});
});
beforeEach(async () => { await env.clearFirestore(); });
after(async () => { if (env) await env.cleanup(); });

test('owner can create, list, edit, archive and soft-delete own notes', async () => {
  const db = env.authenticatedContext('alice').firestore();
  await assertSucceeds(setDoc(ref(db), payload()));
  await assertSucceeds(getDocs(collection(db, 'users/alice/notes')));
  await assertSucceeds(updateDoc(ref(db), {title: 'Atualizada', archived: true, syncedAt: serverTimestamp()}));
  await assertSucceeds(updateDoc(ref(db), {deleted: true, syncedAt: serverTimestamp()}));
  await assertFails(updateDoc(ref(db), {deleted: false, syncedAt: serverTimestamp()}));
  await assertFails(deleteDoc(ref(db)));
});
test('anonymous access and cross-user CRUD are rejected', async () => {
  const owner = env.authenticatedContext('alice').firestore();
  await setDoc(ref(owner), payload());
  for (const db of [env.unauthenticatedContext().firestore(), env.authenticatedContext('bob').firestore()]) {
    await assertFails(getDoc(ref(db)));
    await assertFails(getDocs(collection(db, 'users/alice/notes')));
    await assertFails(setDoc(ref(db), payload()));
    await assertFails(updateDoc(ref(db), {title: 'Ataque', syncedAt: serverTimestamp()}));
    await assertFails(deleteDoc(ref(db)));
  }
});
test('ownership cannot be forged on creation or changed later', async () => {
  const db = env.authenticatedContext('alice').firestore();
  await assertFails(setDoc(ref(db), {...payload(), uid: 'bob'}));
  await setDoc(ref(db), payload());
  await assertFails(updateDoc(ref(db), {uid: 'bob', syncedAt: serverTimestamp()}));
});
test('schema, string bounds, types and required fields apply on create AND update', async () => {
  const db = env.authenticatedContext('alice').firestore();
  const invalid = [
    {title: 'x'.repeat(201)}, {content: ''}, {content: 'x'.repeat(100001)},
    {category: 'x'.repeat(61)}, {revision: 'x'.repeat(100)}, {archived: 'false'},
    {updatedAt: -1}, {updatedAt: 'hoje'}, {reminderAt: -1}, {reminderAt: 999999999999999},
    {uid: 'x'.repeat(129)}, {extra: true}, {role: 'admin'}, {syncedAt: new Date(0)},
  ];
  for (const change of invalid) await assertFails(setDoc(ref(db), {...payload(), ...change}));
  await setDoc(ref(db), payload());
  for (const change of invalid) await assertFails(updateDoc(ref(db), {...change,
    syncedAt: 'syncedAt' in change ? change.syncedAt : serverTimestamp()}));
  for (const field of Object.keys(payload())) await assertFails(updateDoc(ref(db), {[field]: deleteField()}));
});
test('categories are private and validated; arbitrary parent/subcollection access is denied', async () => {
  const a = env.authenticatedContext('alice').firestore();
  const b = env.authenticatedContext('bob').firestore();
  const path = `users/alice/categories/${id}`;
  const data = {uid: 'alice', name: 'Faculdade', revision: id, syncedAt: serverTimestamp()};
  await assertSucceeds(setDoc(doc(a, path), data));
  await assertSucceeds(getDocs(collection(a, 'users/alice/categories')));
  await assertFails(getDoc(doc(b, path)));
  await assertFails(setDoc(doc(b, path), data));
  await assertFails(updateDoc(doc(a, path), {name: 'x'.repeat(61), syncedAt: serverTimestamp()}));
  await assertFails(setDoc(doc(a, 'users/alice'), {role: 'admin'}));
  await assertFails(getDoc(doc(a, 'users/bob')));
  await assertFails(setDoc(doc(a, `users/alice/other/${id}`), data));
});
