const express = require('express');
const bodyParser = require('body-parser');

const app = express();
const port = 3000;

app.use(bodyParser.json());

// Dummy credentials for testing
const TEST_USER = 'admin';
const TEST_PASS = 'password';
const TEST_API_KEY = 'test_api_key_12345';

// Authenticate login
app.post('/api/auth/login', (req, res) => {
    const { username, password } = req.body;

    console.log(`[LOGIN ATTEMPT] username: ${username}, password: ${password}`);

    if (username === TEST_USER && password === TEST_PASS) {
        console.log('[LOGIN SUCCESS] Returning API key');
        return res.json({ api_key: TEST_API_KEY });
    } else {
        console.log('[LOGIN FAILED] Invalid credentials');
        return res.status(401).json({ message: 'Invalid username or password' });
    }
});

// Register payment
app.post('/api/register_payment', (req, res) => {
    const authHeader = req.headers['authorization'];

    if (!authHeader || !authHeader.startsWith('Bearer ')) {
        console.log('[PAYMENT FAILED] Missing or invalid authorization header');
        return res.status(401).json({ message: 'Unauthorized' });
    }

    const token = authHeader.split(' ')[1];

    if (token !== TEST_API_KEY) {
        console.log('[PAYMENT FAILED] Invalid API key');
        return res.status(401).json({ message: 'Unauthorized' });
    }

    console.log('\n=====================================');
    console.log('[PAYMENT RECEIVED]');
    console.log('Body:', JSON.stringify(req.body, null, 2));
    console.log('=====================================\n');

    return res.status(200).json({ success: true, message: 'Payment registered successfully' });
});

app.listen(port, '0.0.0.0', () => {
    console.log(`Test server listening at http://localhost:${port}`);
    console.log(`Expected login credentials: username='${TEST_USER}', password='${TEST_PASS}'`);
});
