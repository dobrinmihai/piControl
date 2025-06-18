#!/bin/bash

# Generate SSL certificates for development
echo "Generating SSL certificates for development..."

# Generate private key
openssl genrsa -out key.pem 2048

# Generate certificate signing request
openssl req -new -key key.pem -out cert.csr -subj "/C=US/ST=State/L=City/O=Organization/CN=localhost"

# Generate self-signed certificate
openssl x509 -req -days 365 -in cert.csr -signkey key.pem -out cert.pem

# Clean up CSR file
rm cert.csr

echo "SSL certificates generated:"
echo "  - key.pem (private key)"
echo "  - cert.pem (certificate)"
echo ""
echo "Note: These are self-signed certificates for development only."
echo "For production, use certificates from a trusted CA."

# Make the script executable
chmod +x generate-certs.sh
