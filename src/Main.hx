import osc.OSCServer;
import osc.OSCMessage;
import osc.OSCMessage.OSCType;

/**
 * Main application entry point for the Haxe OSC Server
 */
class Main {
    static function main() {
        trace("=== Haxe OSC Server ===");
        trace("Starting Open Sound Control server...");
        
        // Create and configure OSC server
        var server = new OSCServer(8000);
        
        // Add some custom handlers
        setupCustomHandlers(server);
        
        // Start the server
        server.start();
        
        // Note: The server runs in a blocking loop
        // In a real application, you might want to run this in a separate thread
        // or integrate with an event loop
    }
    
    /**
     * Set up custom message handlers for demonstration
     */
    static function setupCustomHandlers(server:OSCServer):Void {
        // Audio volume control
        server.registerHandler("/audio/volume", function(msg:OSCMessage):OSCMessage {
            if (msg.args.length > 0) {
                var volume = switch(msg.args[0]) {
                    case Float(v): v;
                    case Int(v): v / 100.0;
                    default: 0.0;
                };
                
                // Clamp volume between 0.0 and 1.0
                volume = Math.max(0.0, Math.min(1.0, volume));
                
                trace('Setting audio volume to: $volume');
                // Here you would integrate with actual audio system
                
                return new OSCMessage("/audio/volume/set", [OSCType.Float(volume)]);
            }
            return new OSCMessage("/audio/volume/error", [OSCType.String("No volume value provided")]);
        });
        
        // MIDI note handler
        server.registerHandler("/midi/note", function(msg:OSCMessage):OSCMessage {
            if (msg.args.length >= 2) {
                var note = switch(msg.args[0]) {
                    case Int(v): v;
                    case Float(v): Std.int(v);
                    default: 60;
                };
                var velocity = switch(msg.args[1]) {
                    case Int(v): v;
                    case Float(v): Std.int(v);
                    default: 127;
                };
                
                trace('MIDI Note: $note, Velocity: $velocity');
                // Here you would integrate with MIDI system
                
                return new OSCMessage("/midi/note/played", [
                    OSCType.Int(note), 
                    OSCType.Int(velocity),
                    OSCType.String("note_on")
                ]);
            }
            return new OSCMessage("/midi/note/error", [OSCType.String("Need note and velocity values")]);
        });
        
        // Parameter control with multiple values
        server.registerHandler("/control/param", function(msg:OSCMessage):OSCMessage {
            if (msg.args.length >= 2) {
                var paramName = switch(msg.args[0]) {
                    case String(s): s;
                    default: "unknown";
                };
                var paramValue = switch(msg.args[1]) {
                    case Float(v): v;
                    case Int(v): (v : Float);
                    default: 0.0;
                };
                
                trace('Parameter $paramName set to: $paramValue');
                // Here you would update your application parameters
                
                return new OSCMessage("/control/param/updated", [
                    OSCType.String(paramName),
                    OSCType.Float(paramValue),
                    OSCType.String("success")
                ]);
            }
            return new OSCMessage("/control/param/error", [OSCType.String("Need parameter name and value")]);
        });
        
        // Shutdown command
        server.registerHandler("/system/shutdown", function(msg:OSCMessage):OSCMessage {
            trace("Shutdown command received");
            
            // Send acknowledgment before shutting down
            var response = new OSCMessage("/system/shutdown/ack", [OSCType.String("Shutting down...")]);
            
            // Schedule shutdown after a brief delay to allow response to be sent
            haxe.Timer.delay(function() {
                trace("Shutting down OSC server...");
                server.stop();
                Sys.exit(0);
            }, 100);
            
            return response;
        });
        
        trace("Custom handlers registered:");
        trace("  /audio/volume <float> - Set audio volume (0.0-1.0)");
        trace("  /midi/note <int> <int> - Send MIDI note (note, velocity)");
        trace("  /control/param <string> <float> - Set parameter value");
        trace("  /system/shutdown - Shutdown the server");
    }
}
