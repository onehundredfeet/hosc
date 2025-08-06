#!/usr/bin/env node
/**
 * Simple OSC Test Client in Node.js
 * No external dependencies - uses only Node.js built-ins
 */

const dgram = require('dgram');

class SimpleOSCClient {
    constructor(host = '127.0.0.1', port = 8000) {
        this.host = host;
        this.port = port;
        this.client = dgram.createSocket('udp4');
    }

    // Build OSC message manually (simplified implementation)
    buildOSCMessage(address, ...args) {
        const buffers = [];
        
        // Add address with null termination and padding
        const addressBuf = this.stringToOSCString(address);
        buffers.push(addressBuf);
        
        // Build type tag
        let typeTag = ',';
        for (const arg of args) {
            if (Number.isInteger(arg)) typeTag += 'i';
            else if (typeof arg === 'number') typeTag += 'f';
            else if (typeof arg === 'string') typeTag += 's';
        }
        
        const typeTagBuf = this.stringToOSCString(typeTag);
        buffers.push(typeTagBuf);
        
        // Add arguments
        for (let i = 0; i < args.length; i++) {
            const arg = args[i];
            if (Number.isInteger(arg)) {
                buffers.push(this.intToBuffer(arg));
            } else if (typeof arg === 'number') {
                buffers.push(this.floatToBuffer(arg));
            } else if (typeof arg === 'string') {
                buffers.push(this.stringToOSCString(arg));
            }
        }
        
        return Buffer.concat(buffers);
    }
    
    stringToOSCString(str) {
        const strBuf = Buffer.from(str, 'utf8');
        const nullTerm = Buffer.alloc(1); // null terminator
        const padding = Buffer.alloc((4 - (strBuf.length + 1) % 4) % 4);
        return Buffer.concat([strBuf, nullTerm, padding]);
    }
    
    intToBuffer(value) {
        const buf = Buffer.alloc(4);
        buf.writeInt32BE(value, 0);
        return buf;
    }
    
    floatToBuffer(value) {
        const buf = Buffer.alloc(4);
        buf.writeFloatBE(value, 0);
        return buf;
    }
    
    sendMessage(address, ...args) {
        return new Promise((resolve, reject) => {
            try {
                const message = this.buildOSCMessage(address, ...args);
                this.client.send(message, this.port, this.host, (err) => {
                    if (err) {
                        console.log(`✗ Error sending ${address}: ${err.message}`);
                        reject(err);
                    } else {
                        console.log(`✓ Sent: ${address}(${args.join(', ')})`);
                        resolve();
                    }
                });
            } catch (error) {
                console.log(`✗ Error building ${address}: ${error.message}`);
                reject(error);
            }
        });
    }
    
    close() {
        this.client.close();
    }
}

async function sleep(ms) {
    return new Promise(resolve => setTimeout(resolve, ms));
}

async function runBasicTests(client) {
    console.log('\n=== Basic OSC Tests ===');
    
    await client.sendMessage('/ping');
    await sleep(100);
    
    await client.sendMessage('/echo', 42);
    await client.sendMessage('/echo', 3.14159);
    await client.sendMessage('/echo', 'hello world');
    await client.sendMessage('/echo', 123, 45.67, 'mixed');
    await sleep(100);
    
    await client.sendMessage('/info');
    await sleep(100);
    
    await client.sendMessage('/math/add', 10, 15);
    await client.sendMessage('/math/add', 100, 200);
    await sleep(100);
}

async function runCustomHandlerTests(client) {
    console.log('\n=== Custom Handler Tests ===');
    
    // Audio volume tests (note: only accepts floats in this simple client)
    await client.sendMessage('/audio/volume', 0.75);
    await client.sendMessage('/audio/volume', 1.5);  // Should clamp to 1.0
    await client.sendMessage('/audio/volume');       // Should error - no args
    await sleep(100);
    
    // MIDI note tests
    await client.sendMessage('/midi/note', 60, 127);
    await client.sendMessage('/midi/note', 72, 100);
    await client.sendMessage('/midi/note', 60);      // Should error - not enough args
    await sleep(100);
    
    // Parameter control tests
    await client.sendMessage('/control/param', 'filter_cutoff', 1000.0);
    await client.sendMessage('/control/param', 'reverb_mix', 0.3);
    await client.sendMessage('/control/param', 'delay_time', 500.0);
    await client.sendMessage('/control/param');  // Should error - no args
    await sleep(100);
}

async function runEdgeCaseTests(client) {
    console.log('\n=== Edge Case Tests ===');
    
    // Test unknown addresses
    await client.sendMessage('/unknown/address');
    await client.sendMessage('/test/nonexistent', 1, 2, 3);
    await sleep(100);
    
    // Test large numbers
    await client.sendMessage('/math/add', 999999, 1);
    await client.sendMessage('/math/add', -500, 600);
    await sleep(100);
    
    // Test long strings
    const longString = 'A'.repeat(50);
    await client.sendMessage('/echo', longString);
    await sleep(100);
    
    // Test special characters
    await client.sendMessage('/echo', 'Hello World! 🎵');
    await sleep(100);
}

async function runStressTests(client) {
    console.log('\n=== Stress Tests ===');
    
    console.log('Sending rapid ping messages...');
    const startTime = Date.now();
    
    const promises = [];
    for (let i = 0; i < 20; i++) {
        promises.push(client.sendMessage('/ping'));
        await sleep(10);  // 10ms between messages
    }
    
    await Promise.all(promises);
    const elapsed = (Date.now() - startTime) / 1000;
    console.log(`Sent 20 messages in ${elapsed.toFixed(2)}s (${(20/elapsed).toFixed(1)} msg/s)`);
    
    console.log('Sending batch of mixed messages...');
    for (let i = 0; i < 10; i++) {
        await client.sendMessage('/math/add', i, i*2);
        await client.sendMessage('/audio/volume', i/10.0);
        await client.sendMessage('/echo', `message_${i}`);
        await sleep(5);
    }
    
    await sleep(100);
}

async function main() {
    const host = process.argv[2] || '127.0.0.1';
    const port = parseInt(process.argv[3]) || 8000;
    const testType = process.argv[4] || 'all';
    
    console.log(`Testing OSC server at ${host}:${port}`);
    console.log('Make sure the Haxe OSC server is running!');
    console.log('-'.repeat(50));
    
    const client = new SimpleOSCClient(host, port);
    
    try {
        if (testType === 'basic' || testType === 'all') {
            await runBasicTests(client);
        }
        
        if (testType === 'custom' || testType === 'all') {
            await runCustomHandlerTests(client);
        }
        
        if (testType === 'edge' || testType === 'all') {
            await runEdgeCaseTests(client);
        }
        
        if (testType === 'stress' || testType === 'all') {
            await runStressTests(client);
        }
        
        console.log('\n=== Shutdown Test (commented out) ===');
        console.log('To test shutdown, uncomment the line below:');
        console.log('// await client.sendMessage("/system/shutdown");');
        // await client.sendMessage('/system/shutdown');
        
        console.log('\n=== Testing Complete ===');
        
    } catch (error) {
        console.error('Test error:', error);
    } finally {
        client.close();
    }
}

if (require.main === module) {
    main().catch(console.error);
}
