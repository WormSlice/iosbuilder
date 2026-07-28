const token = 'mlsn.34131d2c738f0026306ef479f2e4dc85df9ef47633f4cdd32506dc35f33b9a1b';

async function test() {
    const payload = {
        from: {
            email: 'contacto@connectapp.com.co',
            name: 'CONNECT'
        },
        to: [
            {
                email: 'test@connectapp.com.co', // Send to self to avoid spamming real users
                name: 'Test'
            }
        ],
        subject: 'Test email from node',
        text: 'This is a test'
    };

    try {
        const response = await fetch('https://api.mailersend.com/v1/email', {
            method: 'POST',
            headers: {
                'Authorization': `Bearer ${token}`,
                'Content-Type': 'application/json'
            },
            body: JSON.stringify(payload)
        });

        const status = response.status;
        console.log('Status:', status);

        if (!response.ok) {
            try {
                const data = await response.json();
                console.log('Error Data:', data);
            } catch (e) {
                console.log('Error Text:', await response.text());
            }
        } else {
            console.log('Success!');
        }
    } catch (err) {
        console.error('Fetch Error:', err);
    }
}

test();
