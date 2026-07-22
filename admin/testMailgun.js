const API_KEY = "0b7c4497295d2319888303bd9120f5f9-ccbfdc2c-c034af37";
const DOMAIN = "connectapp.com.co";
const BASE_URL = "https://api.mailgun.net/v3";

async function run() {
    const response = await fetch(`${BASE_URL}/${DOMAIN}/events?event=accepted&limit=50`, {
        method: 'GET',
        headers: {
            'Authorization': `Basic ${btoa(`api:${API_KEY}`)}`
        }
    });
    
    const eventsData = await response.json();
    const events = eventsData.items || [];
    
    console.log(`Total eventos obtenidos: ${events.length}`);
    
    const incomingEvents = events.filter((e) => {
        const isAcceptedOrStored = e.event === 'accepted' || e.event === 'stored';
        const toHeader = (e.message?.headers?.to || '').toLowerCase();
        const fromHeader = (e.message?.headers?.from || '').toLowerCase();
        
        const isConnectRecipient = e.recipient?.includes('connectapp.com.co') || 
                                   toHeader.includes('connectapp.com.co') || 
                                   toHeader.includes('@connect.com') ||
                                   (e['mailing-list'] && e['mailing-list'].address?.includes('connectapp.com.co'));
        
        const isNotFromConnect = !fromHeader.includes('connectapp.com.co') && !fromHeader.includes('@connect.com');

        return isAcceptedOrStored && isConnectRecipient && isNotFromConnect;
    });

    console.log(`Eventos que pasaron el filtro: ${incomingEvents.length}`);
    incomingEvents.slice(0, 5).forEach(e => {
        console.log(`- ID: ${e.id}, Event: ${e.event}, To: ${e.message?.headers?.to}, From: ${e.message?.headers?.from}`);
        console.log(`  Storage URL exists: ${!!(e.storage && e.storage.url)}`);
    });
}

run();
