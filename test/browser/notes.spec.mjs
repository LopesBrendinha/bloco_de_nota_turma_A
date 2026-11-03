import {test, expect} from '@playwright/test';
import {mkdir, writeFile, readFile} from 'node:fs/promises';

const production = Boolean(process.env.E2E_ALLOW_PRODUCTION_TEST_DATA);
const config = production ? JSON.parse(await readFile('config/firebase.local.json','utf8')) : null;
if (production && process.env.E2E_ALLOW_PRODUCTION_TEST_DATA !== config.FIREBASE_PROJECT_ID) throw new Error('Confirme o projeto de teste explicitamente.');
const evidencePath = name => 'docs/evidencias/' + name.replace('emulador',production ? 'firebase-real' : 'emulador');
const authEndpoint = production ? 'https://identitytoolkit.googleapis.com/v1' : 'http://127.0.0.1:9099/identitytoolkit.googleapis.com/v1';
const firestoreEndpoint = production ? `https://firestore.googleapis.com/v1/projects/${config.FIREBASE_PROJECT_ID}/databases/(default)/documents` : 'http://127.0.0.1:8080/v1/projects/demo-bloco-notas/databases/(default)/documents';
async function fill(locator, text) {
  await locator.click();
  await locator.fill(text);
  await expect(locator).toHaveValue(text);
}
async function accessibility(page) {
  const placeholder = page.locator('flt-semantics-placeholder');
  await expect(placeholder).toBeAttached();
  await placeholder.evaluate(el => el.click());
}
async function login(page, email, password) {
  await page.goto('/'); await accessibility(page);
  await fill(page.getByRole('textbox', {name:'seu@email.com', exact:true}), email);
  await fill(page.getByRole('textbox', {name:'Digite sua senha', exact:true}), password);
  await page.getByRole('button', {name:'Entrar', exact:true}).click();
  await expect(page.getByText('Meu bloco de notas', {exact:true})).toBeVisible();
}

test('registration, local/cloud CRUD, search, archive, offline queue and fresh installation', async ({page, browser, request}) => {
  const errors = [];
  page.on('pageerror', e => errors.push(e.message));
  const email = `aluno-${Date.now()}@example.test`;
  // Fictitious credentials, valid only in the local Auth emulator.
  const password = production ? crypto.randomUUID() : 'somente-emulador-123';
  await mkdir('docs/evidencias', {recursive:true});
  await page.goto('/'); await accessibility(page);
  await page.getByRole('button', {name:'Ainda não possui uma conta? Cadastre-se'}).click();
  await expect(page.getByText('Criar Conta', {exact:true})).toBeVisible();
  await fill(page.getByRole('textbox', {name:'seu@email.com', exact:true}), email);
  await fill(page.getByRole('textbox', {name:'Digite sua senha', exact:true}), password);
  await fill(page.getByRole('textbox', {name:'Digite novamente', exact:true}), password);
  await page.getByRole('button', {name:'Criar minha conta', exact:true}).click();
  await expect(page.getByText('Meu bloco de notas', {exact:true})).toBeVisible();
  await page.getByRole('button', {name:'Nova nota', exact:true}).click();
  await fill(page.getByRole('textbox', {name:'Título', exact:true}), 'Plano de estudos');
  await fill(page.getByRole('textbox', {name:/^Conteúdo/}), 'Revisar SQLite, Firestore e sincronização.');
  await page.getByRole('button', {name:'Criar categoria', exact:true}).click();
  await fill(page.getByRole('textbox', {name:'Nome', exact:true}), 'Faculdade');
  await page.getByRole('button', {name:'Criar', exact:true}).click();
  await expect(page.getByRole('button', {name:'Categoria Faculdade',exact:true})).toBeVisible();
  await page.getByRole('button', {name:'Salvar', exact:true}).click();
  await expect(page.getByRole('group', {name:/^Plano de estudos /})).toBeVisible();
  await expect(page.getByRole('group', {name:/^Plano de estudos .*Na nuvem$/})).toBeVisible();
  await page.screenshot({path:evidencePath('01-notas-sincronizadas-emulador.png')});
  const auth = await (await request.post(`${authEndpoint}/accounts:signInWithPassword?key=${config?.FIREBASE_API_KEY ?? 'demo-key'}`,
    {data:{email,password,returnSecureToken:true}})).json();
  expect(auth.localId).toBeTruthy();
  const headers = {Authorization:`Bearer ${auth.idToken}`};
  const cloud = async () => {
    const response = await request.get(`${firestoreEndpoint}/users/${auth.localId}/notes`, {headers});
    expect(response.ok()).toBeTruthy(); return (await response.json()).documents ?? [];
  };
  const docs = await cloud();
  expect(docs).toHaveLength(1);
  expect(docs[0].fields.title.stringValue).toBe('Plano de estudos');
  expect(docs[0].fields.category.stringValue).toBe('Faculdade');
  const cloudId = docs[0].name.split('/').at(-1);
  expect((await request.get(`${firestoreEndpoint}/users/${auth.localId}/notes/${cloudId}`)).status()).toBe(403);
  const search = page.getByRole('textbox', {name:'Pesquisar no título ou conteúdo', exact:true});
  await fill(search, 'FIRESTORE');
  await expect(page.getByRole('group', {name:/^Plano de estudos /})).toBeVisible();
  await page.screenshot({path:evidencePath('02-pesquisa-emulador.png')});
  await fill(search, 'não existe');
  await expect(page.getByText('Nenhuma nota corresponde à pesquisa.', {exact:true})).toBeVisible();
  await fill(search, '');
  await page.getByRole('button', {name:'Arquivar', exact:true}).click();
  await expect(page.getByRole('group', {name:/^Plano de estudos /})).toBeHidden();
  await page.getByRole('checkbox', {name:'Arquivadas',exact:true}).click();
  await expect(page.getByRole('group', {name:/^Plano de estudos /})).toBeVisible();
  await expect.poll(async () => (await cloud())[0].fields.archived.booleanValue).toBe(true);
  await page.screenshot({path:evidencePath('03-arquivadas-emulador.png')});
  await page.getByRole('button', {name:'Desarquivar', exact:true}).click();
  await page.getByRole('checkbox', {name:'Ativas',exact:true}).click();
  await page.getByRole('group', {name:/^Plano de estudos /}).click();
  await fill(page.getByRole('textbox', {name:'Título', exact:true}), 'Plano de estudos atualizado');
  await page.getByRole('button', {name:'Salvar', exact:true}).click();
  await expect.poll(async () => (await cloud())[0].fields.title.stringValue).toBe('Plano de estudos atualizado');

  const secondEmail = `outro-${Date.now()}@example.test`;
  const second = await browser.newContext({viewport:{width:1280,height:900}});
  try {
    const other = await second.newPage();
    await login(other,email,password);
    await expect(other.getByRole('group', {name:/^Plano de estudos atualizado /})).toBeVisible();
    await other.screenshot({path:evidencePath('04-outra-instalacao-emulador.png')});
    // A second user must not see the first user's local cache.
    await other.getByRole('button', {name:'Sair', exact:true}).click();
    await expect(other.getByRole('textbox',{name:'seu@email.com',exact:true})).toBeVisible();
    await other.getByRole('button', {name:'Ainda não possui uma conta? Cadastre-se'}).click();
    await expect(other.getByText('Criar Conta', {exact:true})).toBeVisible();
    await fill(other.getByRole('textbox', {name:'seu@email.com', exact:true}), secondEmail);
    await fill(other.getByRole('textbox', {name:'Digite sua senha', exact:true}), password);
    await fill(other.getByRole('textbox', {name:'Digite novamente', exact:true}), password);
    await other.getByRole('button', {name:'Criar minha conta', exact:true}).click();
    await expect(other.getByText('Suas ideias começam aqui. Crie uma nota!', {exact:true})).toBeVisible();
    await expect(other.getByRole('group', {name:/^Plano de estudos atualizado /})).toBeHidden();
  } finally { await second.close(); }
  const otherAuth = await (await request.post(`${authEndpoint}/accounts:signInWithPassword?key=${config?.FIREBASE_API_KEY ?? 'demo-key'}`,{data:{email:secondEmail,password,returnSecureToken:true}})).json();
  expect(otherAuth.idToken).toBeTruthy();
  expect((await request.get(`${firestoreEndpoint}/users/${auth.localId}/notes/${cloudId}`,{headers:{Authorization:`Bearer ${otherAuth.idToken}`}})).status()).toBe(403);

  await page.context().setOffline(true);
  await page.getByRole('button', {name:'Nova nota', exact:true}).click();
  await fill(page.getByRole('textbox', {name:'Título', exact:true}), 'Nota criada sem internet');
  await fill(page.getByRole('textbox', {name:/^Conteúdo/}), 'Esta nota deve sobreviver à falha de conexão.');
  await page.getByRole('button', {name:'Salvar', exact:true}).click();
  await expect(page.getByRole('group', {name:/^Nota criada sem internet /})).toBeVisible();
  await expect(page.getByRole('group', {name:/Envio pendente$/})).toBeVisible();
  await page.screenshot({path:evidencePath('05-fila-offline-emulador.png')});
  expect(await cloud()).toHaveLength(1);
  await page.context().setOffline(false);
  await expect(page.getByRole('button', {name:/^Sincronizar agora/})).toBeEnabled({timeout:40000});
  await page.getByRole('button', {name:/^Sincronizar agora/}).click();
  await expect.poll(async () => (await cloud()).length, {timeout:40000}).toBe(2);
  await expect(page.getByRole('group', {name:/Envio pendente$/})).toHaveCount(0);
  await page.reload(); await accessibility(page);
  await expect(page.getByRole('group', {name:/^Nota criada sem internet /})).toBeVisible();
  // Delete through the UI and verify the durable tombstone in Firestore.
  await page.getByRole('button', {name:'Excluir nota', exact:true}).first().click();
  await page.getByRole('button', {name:'Excluir', exact:true}).click();
  await expect.poll(async () => (await cloud()).filter(d => d.fields.deleted.booleanValue).length).toBe(1);

  const ui = await page.context().newPage();
  if (production) {
    await ui.setExtraHTTPHeaders(headers);
    await ui.goto(`${firestoreEndpoint}/users/${auth.localId}/notes/${cloudId}`);
  } else {
    await ui.goto(`http://127.0.0.1:4000/firestore/default/data/users/${auth.localId}/notes/${cloudId}`);
  }
  await ui.waitForTimeout(2500);
  await ui.screenshot({path:'test-results/firestore-response.png',fullPage:true});
  await writeFile('test-results/resultado.json', JSON.stringify({
    environment:production ? 'Cloud Firestore production — authenticated REST verification' : 'Firebase Emulator Suite — not production', project:config?.FIREBASE_PROJECT_ID ?? 'demo-bloco-notas',
    verifiedAt:new Date().toISOString(), checks:['registration','local CRUD','Firestore CRUD with tombstones',
      'custom category','title/content search','archive/unarchive','fresh installation recovery',
      'user isolation','offline outbox','reconnection upload','SQLite survives page reload'],
    documents:(await cloud()).map(d => ({id:d.name.split('/').at(-1),fields:d.fields})),
    pageErrors:errors,
  },null,2));
  expect(errors).toEqual([]);
});
