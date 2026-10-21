// Automated tests for firestore.rules (user-based access control).
//
// They run against Firebase's local Firestore emulator, never the real database:
//   firebase emulators:exec --only firestore --project demo-my-tasks "npm --prefix rules-tests test"
//
// Each test plays one signed-in user (alice, bob, or carol) and tries one request.
// assertSucceeds = the rules must ALLOW it. assertFails = the rules must REFUSE it.

import { readFileSync } from 'node:fs';
import { after, before, beforeEach, describe, test } from 'node:test';

import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from '@firebase/rules-unit-testing';
import {
  addDoc,
  arrayRemove,
  arrayUnion,
  collection,
  deleteDoc,
  doc,
  getDoc,
  getDocs,
  query,
  setDoc,
  updateDoc,
  where,
} from 'firebase/firestore';

let env;

before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'demo-my-tasks',
    firestore: {
      rules: readFileSync(new URL('../firestore.rules', import.meta.url), 'utf8'),
    },
  });
});

after(async () => {
  await env.cleanup();
});

// Fresh data before every test, written with the rules switched off.
beforeEach(async () => {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    await setDoc(doc(db, 'tasks/aliceTask'), { title: "Alice's task", ownerId: 'alice', isDone: false });
    await setDoc(doc(db, 'tasks/bobTask'), { title: "Bob's task", ownerId: 'bob', isDone: false });

    // Alice owns a shared list and added Bob. Bob owns a list he shared with nobody.
    await setDoc(doc(db, 'lists/aliceList'), { name: "Alice's Group", ownerId: 'alice', memberIds: ['alice', 'bob'] });
    await setDoc(doc(db, 'lists/aliceList/tasks/sharedTask'), { title: 'Shared task', ownerId: 'alice', isDone: false });
    await setDoc(doc(db, 'lists/bobList'), { name: "Bob's Group", ownerId: 'bob', memberIds: ['bob'] });
    await setDoc(doc(db, 'lists/bobList/tasks/bobSharedTask'), { title: "Bob's group task", ownerId: 'bob', isDone: false });

    await setDoc(doc(db, 'users/alice'), { email: 'alice@example.com', displayName: 'Alice' });
    await setDoc(doc(db, 'emails/alice@example.com'), { uid: 'alice' });
  });
});

// One Firestore handle per pretend user. The email goes into the sign-in token,
// exactly like request.auth.token.email in the real app.
const alice = () => env.authenticatedContext('alice', { email: 'alice@example.com' }).firestore();
const bob = () => env.authenticatedContext('bob', { email: 'bob@example.com' }).firestore();
const carol = () => env.authenticatedContext('carol', { email: 'carol@example.com' }).firestore();
const signedOut = () => env.unauthenticatedContext().firestore();

const newTask = (ownerId) => ({ title: 'New task', ownerId, isDone: false });

describe('personal tasks: only the owner', () => {
  test('the owner can read their own task', async () => {
    await assertSucceeds(getDoc(doc(alice(), 'tasks/aliceTask')));
  });

  test('the owner can list their tasks when the query filters by ownerId', async () => {
    const db = alice();
    await assertSucceeds(getDocs(query(collection(db, 'tasks'), where('ownerId', '==', 'alice'))));
  });

  test('a query WITHOUT the owner filter is refused (rules are not filters)', async () => {
    await assertFails(getDocs(collection(alice(), 'tasks')));
  });

  test("IDOR: reading someone else's task by its ID is refused", async () => {
    await assertFails(getDoc(doc(alice(), 'tasks/bobTask')));
  });

  test("IDOR: updating someone else's task by its ID is refused", async () => {
    await assertFails(updateDoc(doc(alice(), 'tasks/bobTask'), { isDone: true }));
  });

  test("IDOR: deleting someone else's task by its ID is refused", async () => {
    await assertFails(deleteDoc(doc(alice(), 'tasks/bobTask')));
  });

  test('creating a task owned by yourself is allowed', async () => {
    await assertSucceeds(addDoc(collection(alice(), 'tasks'), newTask('alice')));
  });

  test('creating a task in someone else\'s name is refused', async () => {
    await assertFails(addDoc(collection(alice(), 'tasks'), newTask('bob')));
  });

  test('creating a task with no owner is refused', async () => {
    await assertFails(addDoc(collection(alice(), 'tasks'), { title: 'Ownerless', isDone: false }));
  });

  test('the owner can update their own task', async () => {
    await assertSucceeds(updateDoc(doc(alice(), 'tasks/aliceTask'), { isDone: true }));
  });

  test('giving your task away (changing ownerId) is refused', async () => {
    await assertFails(updateDoc(doc(alice(), 'tasks/aliceTask'), { ownerId: 'bob' }));
  });

  test('the owner can delete their own task', async () => {
    await assertSucceeds(deleteDoc(doc(alice(), 'tasks/aliceTask')));
  });

  test('a signed-out request is refused', async () => {
    await assertFails(getDoc(doc(signedOut(), 'tasks/aliceTask')));
  });
});

describe('shared lists: members see them, the owner manages them', () => {
  test('a member can read the list', async () => {
    await assertSucceeds(getDoc(doc(bob(), 'lists/aliceList')));
  });

  test('a non-member cannot read the list', async () => {
    await assertFails(getDoc(doc(carol(), 'lists/aliceList')));
  });

  test('a user can query the lists they belong to', async () => {
    const db = bob();
    await assertSucceeds(getDocs(query(collection(db, 'lists'), where('memberIds', 'array-contains', 'bob'))));
  });

  test("IDOR: Alice cannot read Bob's list, which she was never added to", async () => {
    await assertFails(getDoc(doc(alice(), 'lists/bobList')));
  });

  test('creating a list you own, with yourself as a member, is allowed', async () => {
    await assertSucceeds(addDoc(collection(carol(), 'lists'), { name: "Carol's Group", ownerId: 'carol', memberIds: ['carol'] }));
  });

  test('creating a list in someone else\'s name is refused', async () => {
    await assertFails(addDoc(collection(carol(), 'lists'), { name: 'Fake', ownerId: 'alice', memberIds: ['alice', 'carol'] }));
  });

  test('creating a list you are not a member of is refused', async () => {
    await assertFails(addDoc(collection(carol(), 'lists'), { name: 'Odd', ownerId: 'carol', memberIds: [] }));
  });

  test('the owner can add a member', async () => {
    await assertSucceeds(updateDoc(doc(alice(), 'lists/aliceList'), { memberIds: arrayUnion('carol') }));
  });

  test('a member who is not the owner cannot add members', async () => {
    await assertFails(updateDoc(doc(bob(), 'lists/aliceList'), { memberIds: arrayUnion('carol') }));
  });

  test('the owner can remove a member', async () => {
    await assertSucceeds(updateDoc(doc(alice(), 'lists/aliceList'), { memberIds: arrayRemove('bob') }));
  });

  test('the owner cannot remove themselves from their own list', async () => {
    await assertFails(updateDoc(doc(alice(), 'lists/aliceList'), { memberIds: arrayRemove('alice') }));
  });

  test('the owner cannot hand the list to someone else', async () => {
    await assertFails(updateDoc(doc(alice(), 'lists/aliceList'), { ownerId: 'bob' }));
  });

  test('the owner can delete the list', async () => {
    await assertSucceeds(deleteDoc(doc(alice(), 'lists/aliceList')));
  });

  test('a member who is not the owner cannot delete the list', async () => {
    await assertFails(deleteDoc(doc(bob(), 'lists/aliceList')));
  });
});

describe("tasks inside a shared list: members only", () => {
  test("a member can read the list's tasks", async () => {
    await assertSucceeds(getDocs(collection(bob(), 'lists/aliceList/tasks')));
  });

  test("a non-member cannot read the list's tasks", async () => {
    await assertFails(getDocs(collection(carol(), 'lists/aliceList/tasks')));
  });

  test("IDOR: reading one task in a list you're not in is refused", async () => {
    await assertFails(getDoc(doc(alice(), 'lists/bobList/tasks/bobSharedTask')));
  });

  test('a member can add a task stamped with their own ID', async () => {
    await assertSucceeds(addDoc(collection(bob(), 'lists/aliceList/tasks'), newTask('bob')));
  });

  test("a member cannot add a task in another member's name", async () => {
    await assertFails(addDoc(collection(bob(), 'lists/aliceList/tasks'), newTask('alice')));
  });

  test('a non-member cannot add tasks', async () => {
    await assertFails(addDoc(collection(carol(), 'lists/aliceList/tasks'), newTask('carol')));
  });

  test('a member can update a task in the list', async () => {
    await assertSucceeds(updateDoc(doc(bob(), 'lists/aliceList/tasks/sharedTask'), { isDone: true }));
  });

  test("a member cannot change who created a task", async () => {
    await assertFails(updateDoc(doc(bob(), 'lists/aliceList/tasks/sharedTask'), { ownerId: 'bob' }));
  });

  test('a member can delete a task in the list', async () => {
    await assertSucceeds(deleteDoc(doc(bob(), 'lists/aliceList/tasks/sharedTask')));
  });
});

describe('the user directory: look up one, never list all', () => {
  test("a signed-in user can read one profile by its ID", async () => {
    await assertSucceeds(getDoc(doc(bob(), 'users/alice')));
  });

  test('listing every profile is refused', async () => {
    await assertFails(getDocs(collection(bob(), 'users')));
  });

  test('a signed-out request cannot read profiles', async () => {
    await assertFails(getDoc(doc(signedOut(), 'users/alice')));
  });

  test('you can write your own profile with your real email', async () => {
    await assertSucceeds(setDoc(doc(bob(), 'users/bob'), { email: 'bob@example.com', displayName: 'Bob' }));
  });

  test("you cannot write someone else's profile", async () => {
    await assertFails(setDoc(doc(bob(), 'users/alice'), { email: 'alice@example.com', displayName: 'Hacked' }));
  });

  test('you cannot put a different email on your profile', async () => {
    await assertFails(setDoc(doc(bob(), 'users/bob'), { email: 'alice@example.com', displayName: 'Bob' }));
  });

  test('a signed-in user can look up one exact email', async () => {
    await assertSucceeds(getDoc(doc(bob(), 'emails/alice@example.com')));
  });

  test('listing every email is refused', async () => {
    await assertFails(getDocs(collection(bob(), 'emails')));
  });

  test('you can register your own email in the lookup', async () => {
    await assertSucceeds(setDoc(doc(bob(), 'emails/bob@example.com'), { uid: 'bob' }));
  });

  test("you cannot claim someone else's email", async () => {
    await assertFails(setDoc(doc(bob(), 'emails/carol@example.com'), { uid: 'bob' }));
  });

  test('you cannot point your email at another account', async () => {
    await assertFails(setDoc(doc(bob(), 'emails/bob@example.com'), { uid: 'alice' }));
  });

  test('you can remove your own old email entry', async () => {
    await assertSucceeds(deleteDoc(doc(alice(), 'emails/alice@example.com')));
  });

  test("you cannot remove someone else's email entry", async () => {
    await assertFails(deleteDoc(doc(bob(), 'emails/alice@example.com')));
  });
});
