const sms = `Dear SURAFEL 
You have received ETB 4,400.00 from Yeabtsega Abate(2519****8875) 101713 on 03/03/2026 17:45:46. Your transaction number is DC30DSL76U. Your current E-Money Account balance is ETB 4,404.00.
Thank you for using telebirr
Ethio telecom`;

const normalized = sms.replace(/\n/g, ' ').trim();

// New Variant D
const amountMatchD = normalized.match(/received\s+ETB\s*([\d,]+\.?\d*)/i);
const senderMatchD = normalized.match(/from\s+([a-zA-Z\s]+?)\s*\(\d+\*\*\*\*\d+\)/i);
const refMatchD = normalized.match(/transaction number is\s+([A-Z0-9]+)/i);

console.log('--- Variant D ---');
console.log('amountMatch:', amountMatchD ? amountMatchD[1] : null);
console.log('senderMatch:', senderMatchD ? senderMatchD[1] : null);
console.log('refMatch:', refMatchD ? refMatchD[1] : null);
