package osc;

import osc.OSCMessage;
import osc.OSCMessage.OSCHandler;

/**
 * Registry for managing OSC message handlers
 */
class OSCHandlerRegistry {
    private var handlers:Map<String, OSCHandler>;
    private var defaultHandler:OSCHandler;
    
    public function new() {
        handlers = new Map<String, OSCHandler>();
        defaultHandler = null;
    }
    
    /**
     * Register a handler for a specific address pattern
     */
    public function registerHandler(address:String, handler:OSCHandler):Void {
        handlers.set(address, handler);
    }
    
    /**
     * Set a default handler for unmatched addresses
     */
    public function setDefaultHandler(handler:OSCHandler):Void {
        defaultHandler = handler;
    }
    
    /**
     * Process an OSC message and return a response (if any)
     */
    public function processMessage(message:OSCMessage):OSCMessage {
        var handler = handlers.get(message.address);
        
        if (handler != null) {
            return handler(message);
        } else if (defaultHandler != null) {
            return defaultHandler(message);
        }
        
        // No handler found, return null (no response)
        return null;
    }
    
    /**
     * Get all registered address patterns
     */
    public function getRegisteredAddresses():Array<String> {
        var addresses:Array<String> = [];
        for (address in handlers.keys()) {
            addresses.push(address);
        }
        return addresses;
    }
}
