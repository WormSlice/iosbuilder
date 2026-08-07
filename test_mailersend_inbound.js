const token = 'mlsn.34131d2c738f0026306ef479f2e4dc85df9ef47633f4cdd32506dc35f33b9a1b';

async function checkMailerSend() {
    console.log('--- Checking Domains ---');
    try {
        const res = await fetch('https://api.mailersend.com/v1/domains', {
            headers: { 'Authorization': `Bearer ${token}` }
        });
        const domains = await res.json();
        console.log('Domains:', JSON.stringify(domains, null, 2));
        
        if (domains.data && domains.data.length > 0) {
            const domainId = domains.data[0].id;
            console.log('\n--- Checking Activity for domain', domainId, '---');
            const actRes = await fetch(`https://api.mailersend.com/v1/activity/${domainId}`, {
                headers: { 'Authorization': `Bearer ${token}` }
            });
            const activity = await actRes.json();
            console.log('Activity:', JSON.stringify(activity, null, 2));
        }
    } catch (e) {
        console.error('Error:', e);
    }

    console.log('\n--- Checking Inbound Routes ---');
    try {
        const inRes = await fetch('https://api.mailersend.com/v1/inbound', {
            headers: { 'Authorization': `Bearer ${token}` }
        });
        const inbound = await inRes.json();
        console.log('Inbound Routes:', JSON.stringify(inbound, null, 2));
    } catch (e) {
        console.error('Error inbound:', e);
    }
}

checkMailerSend();
