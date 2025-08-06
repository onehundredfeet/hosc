#!/usr/bin/env node
/**
 * Test client for the Async OSC Server
 * Tests concurrent message handling and responsiveness
 */

const dgram = require('dgram');

class AsyncOSCTestClient {
    constructor(host = '127.0.0.1', port = 8001) {
        this.host = host;
        this.port = port;
        this.client = dgram.createSocket('udp4');
    }

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
        const nullTerm = Buffer.alloc(1);
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

async function testBasicAsync(client) {
    console.log('\\n=== Basic Async Tests ===');
    
    await client.sendMessage('/ping');
    await sleep(50);
    
    await client.sendMessage('/async/test', 'Hello Async World!');
    await sleep(100);
    
    await client.sendMessage('/async/stats');
    await sleep(100);
    
    await client.sendMessage('/info');
    await sleep(100);
}

async function testLoadSimulation(client) {
    console.log('\\n=== Load Simulation Tests ===');
    
    // Test different load levels
    for (let load = 10; load <= 50; load += 10) {
        await client.sendMessage('/async/load', load);
        await sleep(20); // Short delay between requests
    }
    
    await sleep(200); // Wait for processing
    await client.sendMessage('/async/stats');
    await sleep(100);
}

async function testConcurrentMessages(client) {
    console.log('\\n=== Concurrent Message Tests ===');
    
    // Send multiple messages rapidly
    const promises = [];
    for (let i = 0; i < 20; i++) {
        promises.push(client.sendMessage('/async/batch', i));
        if (i % 5 === 0) {
            promises.push(client.sendMessage('/async/test', `Concurrent test ${i}`));
        }
    }
    
    await Promise.all(promises);
    console.log('All concurrent messages sent');
    
    await sleep(500); // Wait for processing
    await client.sendMessage('/async/stats');
    await sleep(100);
}

async function testStressLoad(client) {
    console.log('\\n=== Stress Test ===');
    
    const startTime = Date.now();
    const messageCount = 100;
    
    console.log(`Sending ${messageCount} messages rapidly...`);
    
    for (let i = 0; i < messageCount; i++) {
        // Mix of different message types
        if (i % 4 === 0) {
            await client.sendMessage('/async/test', `Stress test ${i}`);
        } else if (i % 4 === 1) {
            await client.sendMessage('/async/load', Math.floor(Math.random() * 20) + 1);
        } else if (i % 4 === 2) {
            await client.sendMessage('/async/batch', i);
        } else {
            await client.sendMessage('/ping');
        }
        
        // Very short delay to not overwhelm
        await sleep(5);
    }
    
    const elapsed = (Date.now() - startTime) / 1000;
    console.log(`Sent ${messageCount} messages in ${elapsed.toFixed(2)}s (${(messageCount/elapsed).toFixed(1)} msg/s)`);
    
    // Wait for processing and get final stats
    await sleep(1000);
    await client.sendMessage('/async/stats');
    await sleep(100);
}

async function testResponsiveness(client) {
    console.log('\\n=== Responsiveness Test ===');
    
    // Send messages that cause heavy processing
    console.log('Sending heavy load messages...');
    for (let i = 0; i < 5; i++) {
        await client.sendMessage('/async/load', 80); // Heavy load
        await sleep(10);
    }
    
    // Immediately send quick messages to test responsiveness
    console.log('Testing responsiveness during heavy load...');
    for (let i = 0; i < 10; i++) {
        await client.sendMessage('/ping');
        await sleep(5);
    }
    
    await sleep(500);
    await client.sendMessage('/async/stats');
    await sleep(100);
}

async function main() {
    const host = process.argv[2] || '127.0.0.1';
    const port = parseInt(process.argv[3]) || 8001;
    
    console.log(`Testing Async OSC server at ${host}:${port}`);
    console.log('Make sure the AsyncServerExample is running!');
    console.log('-'.repeat(60));
    
    const client = new AsyncOSCTestClient(host, port);
    
    try {
        await testBasicAsync(client);
        await testLoadSimulation(client);
        await testConcurrentMessages(client);
        await testStressLoad(client);
        await testResponsiveness(client);
        
        console.log('\\n=== Shutdown Test ===');
        console.log('Sending shutdown command...');
        await client.sendMessage('/async/shutdown');
        await sleep(100);
        
        console.log('\\n=== Async Testing Complete ===');
        
    } catch (error) {
        console.error('Test error:', error);
    } finally {
        client.close();
    }
}

if (require.main === module) {
    main().catch(console.error);
}
