async function testWorkerPost() {
    console.log('--- Simulating Cloudflare Worker POST to Firestore ---');
    const payload = {
        fields: {
            from: { stringValue: "cliente.prueba@gmail.com" },
            to: { stringValue: "contacto@connectapp.com.co" },
            subject: { stringValue: "Consulta de prueba en tiempo real 🔥" },
            message: { stringValue: "Hola equipo de CONNECT, este es un mensaje de prueba para verificar la recepción en vivo en el Panel Admin." },
            status: { stringValue: "received" },
            category: { stringValue: "principal" },
            timestamp: { timestampValue: new Date().toISOString() }
        }
    };

    try {
        const res = await fetch("https://firestore.googleapis.com/v1/projects/connect2025-37b7c/databases/(default)/documents/mail", {
            method: "POST",
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify(payload)
        });
        const data = await res.json();
        console.log('Result:', JSON.stringify(data, null, 2));
    } catch (e) {
        console.error('Error:', e);
    }
}

testWorkerPost();
