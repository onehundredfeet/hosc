package osc;

import sys.net.UdpSocket;
import sys.net.Host;
import sys.net.Address;
import haxe.io.Bytes;
import sys.thread.Thread;
import sys.thread.Deque;
import sys.thread.Mutex;
import osc.OSCMessage;
import osc.OSCMessage.OSCHandler;
import osc.OSCParser;
import osc.OSCBuilder;
import osc.OSCHandlerRegistry;

/**
 * Represents an incoming OSC message with sender information
 */
class OSCIncomingMessage {
    public var message:OSCMessage;
    public var senderAddr:Address;
    public var timestamp:Float;
    
    public function new(message:OSCMessage, senderAddr:Address) {
        this.message = message;
        this.senderAddr = senderAddr;
        this.timestamp = haxe.Timer.stamp();
    }
}

/**
 * Represents an outgoing OSC response
 */
class OSCOutgoingMessage {
    public var message:OSCMessage;
    public var targetAddr:Address;
    
    public function new(message:OSCMessage, targetAddr:Address) {
        this.message = message;
        this.targetAddr = targetAddr;
    }
}

/**
 * Non-blocking OSC Server that uses threading and synchronized queues
 * 
 * This server runs the UDP listener in a separate thread and uses synchronized
 * queues to communicate between the network thread and the main application thread.
 * This allows the main thread to remain responsive while processing OSC messages.
 */
class OSCServerAsync {
    private var socket:UdpSocket;
    private var port:Int;
    private var isRunning:Bool;
    private var handlerRegistry:OSCHandlerRegistry;
    
    // Threading components
    private var networkThread:Thread;
    private var processingThread:Thread;
    
    // Synchronized queues for thread communication
    private var incomingQueue:Deque<OSCIncomingMessage>;
    private var outgoingQueue:Deque<OSCOutgoingMessage>;
    
    // Synchronization
    private var stateMutex:Mutex;
    private var isNetworkRunning:Bool;
    private var isProcessingRunning:Bool;
    
    // Configuration
    private var maxQueueSize:Int;
    private var processingInterval:Float; // seconds
    
    public function new(port:Int = 8000, maxQueueSize:Int = 1000) {
        this.port = port;
        this.isRunning = false;
        this.maxQueueSize = maxQueueSize;
        this.processingInterval = 0.001; // 1ms processing interval
        
        this.handlerRegistry = new OSCHandlerRegistry();
        this.incomingQueue = new Deque<OSCIncomingMessage>();
        this.outgoingQueue = new Deque<OSCOutgoingMessage>();
        this.stateMutex = new Mutex();
        
        this.isNetworkRunning = false;
        this.isProcessingRunning = false;
        
    }
    
    /**
     * Start the async OSC server
     */
    public function start():Void {
        stateMutex.acquire();
        
        if (isRunning) {
            stateMutex.release();
            trace("OSC Async Server is already running");
            return;
        }
        
        try {
            socket = new UdpSocket();
            socket.bind(new Host("0.0.0.0"), port);
            isRunning = true;
            isNetworkRunning = true;
            isProcessingRunning = true;
            
            stateMutex.release();
            
            trace('OSC Async Server started on port $port');
            trace('Max queue size: $maxQueueSize messages');
            trace('Registered handlers: ${handlerRegistry.getRegisteredAddresses().join(", ")}');
            
            // Start network listener thread
            networkThread = Thread.create(networkThreadFunction);
            
            // Start message processing thread
            processingThread = Thread.create(processingThreadFunction);
            
            trace("Network and processing threads started");
            
        } catch (e:Dynamic) {
            stateMutex.release();
            trace('Failed to start OSC Async server: $e');
        }
    }
    
    /**
     * Stop the async OSC server
     */
    public function stop():Void {
        stateMutex.acquire();
        
        if (!isRunning) {
            stateMutex.release();
            return;
        }
        
        trace("Stopping OSC Async Server...");
        
        isRunning = false;
        isNetworkRunning = false;
        isProcessingRunning = false;
        
        stateMutex.release();
        
        // Give threads time to finish current operations
        Sys.sleep(0.1);
        
        if (socket != null) {
            socket.close();
        }
        
        trace("OSC Async Server stopped");
    }
    
    /**
     * Register a message handler
     */
    public function registerHandler(address:String, handler:OSCHandler):Void {
        handlerRegistry.registerHandler(address, handler);
    }
    
    /**
     * Set default handler for unmatched messages
     */
    public function setDefaultHandler(handler:OSCHandler):Void {
        handlerRegistry.setDefaultHandler(handler);
    }
    
    /**
     * Process pending messages (call this regularly from your main loop)
     * Returns the number of messages processed
     */
    public function processPendingMessages():Int {
        var processedCount = 0;
        var maxBatchSize = 50; // Process up to 50 messages per call
        
        // Process incoming messages
        for (i in 0...maxBatchSize) {
            var incomingMsg = incomingQueue.pop(false); // Non-blocking pop
            if (incomingMsg == null) break;
            
            try {
                trace('Processing: ${incomingMsg.message.toString()} from ${incomingMsg.senderAddr.host}:${incomingMsg.senderAddr.port}');
                
                var response = handlerRegistry.processMessage(incomingMsg.message);
                
                if (response != null) {
                    var outgoingMsg = new OSCOutgoingMessage(response, incomingMsg.senderAddr);
                    
                    // Add to outgoing queue
                    outgoingQueue.add(outgoingMsg);
                    trace('Queued response: ${response.toString()}');
                }
                
                processedCount++;
            } catch (e:Dynamic) {
                trace('Error processing message: $e');
            }
        }
        
        return processedCount;
    }
    
    /**
     * Get queue statistics for monitoring
     */
    public function getQueueStats():{incoming:Int, outgoing:Int, maxSize:Int} {
        // Note: Deque doesn't have a length property, so we'll estimate
        // by attempting to peek at elements
        var incomingCount = 0;
        var outgoingCount = 0;
        
        // Try to estimate queue sizes (this is an approximation)
        var tempIncoming:Array<OSCIncomingMessage> = [];
        while (true) {
            var item = incomingQueue.pop(false);
            if (item == null) break;
            tempIncoming.push(item);
            incomingCount++;
            if (incomingCount > 100) break; // Prevent infinite loop
        }
        
        // Put items back
        for (item in tempIncoming) {
            incomingQueue.add(item);
        }
        
        var tempOutgoing:Array<OSCOutgoingMessage> = [];
        while (true) {
            var item = outgoingQueue.pop(false);
            if (item == null) break;
            tempOutgoing.push(item);
            outgoingCount++;
            if (outgoingCount > 100) break; // Prevent infinite loop
        }
        
        // Put items back
        for (item in tempOutgoing) {
            outgoingQueue.add(item);
        }
        
        return {
            incoming: incomingCount,
            outgoing: outgoingCount,
            maxSize: maxQueueSize
        };
    }
    
    /**
     * Check if the server is running
     */
    public function isServerRunning():Bool {
        stateMutex.acquire();
        var running = isRunning;
        stateMutex.release();
        return running;
    }
    
    /**
     * Network thread function - runs the UDP listener
     */
    private function networkThreadFunction():Void {
        trace("Network thread started");
        var buffer = Bytes.alloc(2048); // 2KB buffer for incoming messages
        
        while (true) {
            stateMutex.acquire();
            var shouldRun = isNetworkRunning;
            stateMutex.release();
            
            if (!shouldRun) break;
            
            try {
                // Read incoming message with timeout
                var senderAddr = new Address();
                var bytesRead = socket.readFrom(buffer, 0, buffer.length, senderAddr);
                
                if (bytesRead > 0) {
                    var data = buffer.sub(0, bytesRead);
                    
                    try {
                        // Parse OSC message
                        var message = OSCParser.parseMessage(data);
                        var incomingMsg = new OSCIncomingMessage(message, senderAddr);
                        
                        // Add to incoming queue
                        incomingQueue.add(incomingMsg);
                        
                    } catch (parseError:Dynamic) {
                        trace('Failed to parse OSC message: $parseError');
                    }
                }
                
                // Small sleep to prevent busy waiting
                Sys.sleep(0.001); // 1ms
                
            } catch (e:Dynamic) {
                stateMutex.acquire();
                var shouldRun = isNetworkRunning;
                stateMutex.release();
                
                if (shouldRun) {
                    trace('Network thread error: $e');
                    Sys.sleep(0.1); // Longer sleep on error
                }
            }
        }
        
        trace("Network thread stopped");
    }
    
    /**
     * Processing thread function - handles outgoing responses
     */
    private function processingThreadFunction():Void {
        trace("Processing thread started");
        
        while (true) {
            stateMutex.acquire();
            var shouldRun = isProcessingRunning;
            stateMutex.release();
            
            if (!shouldRun) break;
            
            try {
                // Process outgoing messages
                var outgoingMsg = outgoingQueue.pop(false); // Non-blocking pop
                
                if (outgoingMsg != null) {
                    try {
                        var responseData = OSCBuilder.buildMessage(outgoingMsg.message);
                        socket.sendTo(responseData, 0, responseData.length, outgoingMsg.targetAddr);
                        trace('Sent response: ${outgoingMsg.message.toString()} to ${outgoingMsg.targetAddr.host}:${outgoingMsg.targetAddr.port}');
                    } catch (sendError:Dynamic) {
                        trace('Failed to send response: $sendError');
                    }
                } else {
                    // No messages to process, sleep briefly
                    Sys.sleep(processingInterval);
                }
                
            } catch (e:Dynamic) {
                stateMutex.acquire();
                var shouldRun = isProcessingRunning;
                stateMutex.release();
                
                if (shouldRun) {
                    trace('Processing thread error: $e');
                    Sys.sleep(0.1); // Longer sleep on error
                }
            }
        }
        
        trace("Processing thread stopped");
    }
    
    /**
     * Set up default message handlers
     */
    public function setupDefaultHandlers():Void {
        // Ping handler
        registerHandler("/ping", function(msg:OSCMessage):OSCMessage {
            trace("Received ping, sending pong (async)");
            return new OSCMessage("/pong", [OSCType.String("pong_async")]);
        });
        
        // Echo handler
        registerHandler("/echo", function(msg:OSCMessage):OSCMessage {
            trace('Echo (async): ${msg.toString()}');
            return new OSCMessage("/echo/response", msg.args);
        });
        
        // Info handler
        registerHandler("/info", function(msg:OSCMessage):OSCMessage {
            var stats = getQueueStats();
            var info = 'Haxe OSC Async Server - Port: $port, Handlers: ${handlerRegistry.getRegisteredAddresses().length}, Queue: ${stats.incoming}/${stats.outgoing}';
            return new OSCMessage("/info/response", [OSCType.String(info)]);
        });
        
        // Queue stats handler
        registerHandler("/queue/stats", function(msg:OSCMessage):OSCMessage {
            var stats = getQueueStats();
            return new OSCMessage("/queue/stats/response", [
                OSCType.Int(stats.incoming),
                OSCType.Int(stats.outgoing),
                OSCType.Int(stats.maxSize)
            ]);
        });
        
        // Set default handler for unknown messages
        setDefaultHandler(function(msg:OSCMessage):OSCMessage {
            trace('Unknown message address (async): ${msg.address}');
            return new OSCMessage("/error", [OSCType.String('Unknown address: ${msg.address}')]);
        });
    }
}
