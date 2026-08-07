const token = 'mlsn.34131d2c738f0026306ef479f2e4dc85df9ef47633f4cdd32506dc35f33b9a1b';
const domainId = 'q3enl6x29o7l2vwr';

async function testEnableInbound() {
    console.log('--- Attempting to update domain settings ---');
    try {
        const res = await fetch(`https://api.mailersend.com/v1/domains/${domainId}`, {
            method: 'PUT',
            headers: {
                'Authorization': `Bearer ${token}`,
                'Content-Type': 'application/json'
            },
            body: JSON.stringify({
                domain_settings: {
                    inbound_routing_enabled: true
                }
            })
        });
        console.log('Status:', res.status);
        console.log('Response:', await res.json());
    } catch (e) {
        console.error('Error:', e);
    }
}

testEnableInbound();
