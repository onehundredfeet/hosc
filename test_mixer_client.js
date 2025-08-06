#!/usr/bin/env node
/**
 * Test client for the Audio Mixer OSC Example
 */

const dgram = require('dgram');

class MixerTestClient {
    constructor(host = '127.0.0.1', port = 9000) {
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

async function testMixer() {
    console.log('=== Audio Mixer OSC Test ===');
    console.log('Testing OSC mixer on port 9000');
    console.log('');
    
    const client = new MixerTestClient();
    
    try {
        // Test master controls
        console.log('Testing master controls...');
        await client.sendMessage('/mixer/master/volume', 0.9);
        await sleep(100);
        await client.sendMessage('/mixer/master/mute', 1);
        await sleep(100);
        await client.sendMessage('/mixer/master/mute', 0);
        await sleep(100);
        
        // Test channel controls
        console.log('\\nTesting channel controls...');
        await client.sendMessage('/mixer/channel/1/volume', 0.8);
        await sleep(100);
        await client.sendMessage('/mixer/channel/1/pan', -0.5);
        await sleep(100);
        await client.sendMessage('/mixer/channel/2/volume', 0.6);
        await sleep(100);
        await client.sendMessage('/mixer/channel/2/pan', 0.5);
        await sleep(100);
        await client.sendMessage('/mixer/channel/3/mute', 1);
        await sleep(100);
        
        // Test multiple channels
        console.log('\\nTesting multiple channels...');
        for (let i = 1; i <= 8; i++) {
            await client.sendMessage(`/mixer/channel/${i}/volume`, i * 0.1);
            await sleep(50);
        }
        
        // Test status query
        console.log('\\nGetting mixer status...');
        await client.sendMessage('/mixer/status');
        await sleep(200);
        
        // Test reset
        console.log('\\nResetting mixer...');
        await client.sendMessage('/mixer/reset');
        await sleep(200);
        
        // Final status check
        console.log('\\nFinal status check...');
        await client.sendMessage('/mixer/status');
        await sleep(200);
        
        console.log('\\n=== Mixer Test Complete ===');
        
    } catch (error) {
        console.error('Test error:', error);
    } finally {
        client.close();
    }
}

if (require.main === module) {
    testMixer().catch(console.error);
}
