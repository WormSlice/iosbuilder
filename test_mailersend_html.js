const token = 'mlsn.34131d2c738f0026306ef479f2e4dc85df9ef47633f4cdd32506dc35f33b9a1b';

async function test() {
    const ctaText = 'TOCA AQUI';
    const ctaLink = 'https://connect2025-37b7c.web.app/';
    const message = 'holaaa';

    const buttonHtml = ctaText && ctaLink ? `
        <div style="margin: 30px 0;">
            <a href="${ctaLink}" style="background-color: #0094FF; color: white; padding: 12px 24px; text-decoration: none; border-radius: 8px; font-weight: bold; font-family: sans-serif; display: inline-block;">
                ${ctaText}
            </a>
        </div>
    ` : '';

    const htmlMessage = `
        <div style="font-family: 'Segoe UI', Roboto, Helvetica, Arial, sans-serif; color: #1a1a1a; max-width: 600px; margin: 0 auto; padding: 40px; border: 1px solid #f0f0f0; rounded: 24px;">
            <h1 style="color: #007AFF; font-size: 22px; font-weight: 900; margin-bottom: 24px; letter-spacing: -0.5px; font-family: 'Inter', sans-serif;">CONNECT APP S.A.S</h1>
            <div style="font-size: 16px; line-height: 1.6; color: #333; margin-bottom: 30px;">
                ${message.replace(/\n/g, '<br>')}
            </div>
            
            ${buttonHtml}
            <div style="margin-top: 40px; border-top: 1px solid #eee; padding-top: 20px;">
                <p style="font-size: 11px; color: #999; text-align: center; margin: 0;">
                    CONNECT  ©  2026. Todos los derechos reservados.
                </p>
            </div>
        </div>
    `;

    const payload = {
        from: {
            email: 'contacto@connectapp.com.co',
            name: 'CONTACTO'
        },
        to: [
            {
                email: 'test@connectapp.com.co',
                name: 'Test'
            }
        ],
        subject: 'Prueba de mensaje',
        text: message,
        html: htmlMessage
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
                console.log('Error Data:', JSON.stringify(data, null, 2));
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
