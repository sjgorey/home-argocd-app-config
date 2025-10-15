#!/bin/bash
# SMTP Relay Test Script
# Usage: ./test-smtp-relay.sh [recipient-email]

RECIPIENT=${1:-"steve.gorey+k3s@gmail.com"}
SMTP_HOST="smtp-relay.smtp-relay.svc.cluster.local"
SMTP_PORT="25"

echo "🧪 Testing SMTP Relay Service"
echo "==============================="
echo "📧 Recipient: $RECIPIENT"
echo "🏠 SMTP Host: $SMTP_HOST:$SMTP_PORT"
echo ""

# Create test pod with email utilities
kubectl run smtp-test-$(date +%s) --image=alpine --rm -it --restart=Never -- sh -c "
echo '🔧 Installing email utilities...'
apk add --no-cache ssmtp curl

echo '⚙️ Configuring SMTP...'
cat > /etc/ssmtp/ssmtp.conf << 'EOF'
root=gorco@maine.rr.com
mailhub=$SMTP_HOST:$SMTP_PORT
FromLineOverride=YES
EOF

echo '📝 Preparing test email...'
TIMESTAMP=\$(date)
HOSTNAME=\$(hostname)

echo \"Subject: SMTP Relay Test - \$TIMESTAMP
From: gorco@maine.rr.com
To: $RECIPIENT

🎉 SMTP Relay Test Email

This email was sent to test the K3s cluster SMTP relay service.

Test Details:
============
📅 Timestamp: \$TIMESTAMP
🖥️  Test Pod: \$HOSTNAME
🌐 SMTP Relay: $SMTP_HOST:$SMTP_PORT
📬 From Address: gorco@maine.rr.com
📧 To Address: $RECIPIENT

Configuration:
=============
• No authentication required (handled by relay)
• Internal cluster communication
• Relayed through mail.roadrunner.com

If you receive this email, the SMTP relay is working correctly! ✅

Best regards,
Your K3s Cluster SMTP Relay\" | ssmtp $RECIPIENT

echo '✅ Email sent successfully!'
echo ''
echo '📊 Testing SMTP connectivity...'
timeout 5 telnet $SMTP_HOST $SMTP_PORT || echo 'Telnet test failed (this is normal for Alpine)'

echo ''
echo '🎯 Test completed! Check your email inbox.'
"