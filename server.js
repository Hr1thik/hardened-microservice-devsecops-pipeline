javascript
const express = require('express');
const app = express();
const PORT = process.env.PORT || 3000;

// Middleware
app.use(express.json());

// Health check endpoint (for K8s liveness/readiness probes)
app.get('/health', (req, res) => {
    res.status(200).json({ status: 'UP', timestamp: new Date() });
});

// Root route
app.get('/', (req, res) => {
    res.json({ message: 'Secure DevSecOps Web Application Running!' });
});

// Start server
app.listen(PORT, () => {
    console.log(`Application listening securely on port ${PORT}`);
});