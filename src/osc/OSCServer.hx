package osc;

import sys.net.UdpSocket;
import sys.net.Host;
import sys.net.Address;
import haxe.io.Bytes;
import osc.OSCMessage;
import osc.OSCMessage.OSCHandler;
import osc.OSCParser;
import osc.OSCBuilder;
import osc.OSCHandlerRegistry;

/**
 * OSC Server that listens for UDP messages and processes them
 */
class OSCServer {
    private var socket:UdpSocket;
    private var port:Int;
    private var isRunning:Bool;
    private var handlerRegistry:OSCHandlerRegistry;
    
    public function new(port:Int = 8000) {
        this.port = port;
        this.isRunning = false;
        this.handlerRegistry = new OSCHandlerRegistry();
        
        // Set up default handlers
        setupDefaultHandlers();
    }
    
    /**
     * Start the OSC server
     */
    public function start():Void {
        if (isRunning) {
            trace("OSC Server is already running");
            return;
        }
        
        try {
            socket = new UdpSocket();
            socket.bind(new Host("0.0.0.0"), port);
            isRunning = true;
            
            trace('OSC Server started on port $port');
            trace('Registered handlers: ${handlerRegistry.getRegisteredAddresses().join(", ")}');
            
            // Start listening loop
            listen();
            
        } catch (e:Dynamic) {
            trace('Failed to start OSC server: $e');
        }
    }
    
    /**
     * Stop the OSC server
     */
    public function stop():Void {
        if (!isRunning) return;
        
        isRunning = false;
        if (socket != null) {
            socket.close();
        }
        trace("OSC Server stopped");
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
     * Main listening loop
     */
    private function listen():Void {
        trace("Listening for OSC messages...");
        
        var buffer = Bytes.alloc(1024); // 1KB buffer for incoming messages
        
        while (isRunning) {
            try {
                // Read incoming message
                var senderAddr = new Address();
                var bytesRead = socket.readFrom(buffer, 0, buffer.length, senderAddr);
                
                if (bytesRead > 0) {
                    var data = buffer.sub(0, bytesRead);
                    trace('Received $bytesRead bytes from ${senderAddr.host}:${senderAddr.port}');
                    
                    // Parse OSC message
                    var message = OSCParser.parseMessage(data);
                    trace('Parsed OSC message: ${message.toString()}');
                    
                    // Process message
                    var response = handlerRegistry.processMessage(message);
                    
                    if (response != null) {
                        // Send response back to sender
                        var responseData = OSCBuilder.buildMessage(response);
                        socket.sendTo(responseData, 0, responseData.length, senderAddr);
                        trace('Sent response: ${response.toString()}');
                    }
                }
            } catch (e:Dynamic) {
                if (isRunning) {
                    trace('Error in OSC server: $e');
                }
            }
        }
    }
    
    /**
     * Set up some default message handlers
     */
    private function setupDefaultHandlers():Void {
        // Ping handler
        registerHandler("/ping", function(msg:OSCMessage):OSCMessage {
            trace("Received ping, sending pong");
            return new OSCMessage("/pong", [OSCType.String("pong")]);
        });
        
        // Echo handler
        registerHandler("/echo", function(msg:OSCMessage):OSCMessage {
            trace('Echo: ${msg.toString()}');
            return new OSCMessage("/echo/response", msg.args);
        });
        
        // Info handler
        registerHandler("/info", function(msg:OSCMessage):OSCMessage {
            var info = 'Haxe OSC Server - Port: $port, Handlers: ${handlerRegistry.getRegisteredAddresses().length}';
            return new OSCMessage("/info/response", [OSCType.String(info)]);
        });
        
        // Test arithmetic handler
        registerHandler("/math/add", function(msg:OSCMessage):OSCMessage {
            if (msg.args.length >= 2) {
                var a = switch(msg.args[0]) {
                    case Int(v): v;
                    case Float(v): Std.int(v);
                    default: 0;
                };
                var b = switch(msg.args[1]) {
                    case Int(v): v;
                    case Float(v): Std.int(v);
                    default: 0;
                };
                var result = a + b;
                trace('Math: $a + $b = $result');
                return new OSCMessage("/math/add/result", [OSCType.Int(result)]);
            }
            return new OSCMessage("/math/add/error", [OSCType.String("Need 2 numeric arguments")]);
        });
        
        // Set default handler for unknown messages
        setDefaultHandler(function(msg:OSCMessage):OSCMessage {
            trace('Unknown message address: ${msg.address}');
            return new OSCMessage("/error", [OSCType.String('Unknown address: ${msg.address}')]);
        });
    }
}
