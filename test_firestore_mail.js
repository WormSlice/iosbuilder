async function checkFirestoreMail() {
    console.log('--- Checking Firestore mail collection ---');
    try {
        const res = await fetch('https://firestore.googleapis.com/v1/projects/connect2025-37b7c/databases/(default)/documents/mail');
        const data = await res.json();
        console.log('Firestore Mail Docs:', JSON.stringify(data, null, 2));
    } catch (e) {
        console.error('Error fetching Firestore:', e);
    }
}

checkFirestoreMail();
