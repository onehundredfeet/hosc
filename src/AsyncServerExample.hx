import osc.OSCServerAsync;
import osc.OSCMessage;
import osc.OSCMessage.OSCType;

/**
 * Example application demonstrating the non-blocking OSC server
 * 
 * This shows how to use OSCServerAsync to handle OSC messages without
 * blocking the main application thread, allowing for responsive GUI
 * applications or other real-time processing.
 */
class AsyncServerExample {
    
    static var server:OSCServerAsync;
    static var isRunning:Bool = true;
    static var frameCount:Int = 0;
    
    static function main() {
        trace("=== Async OSC Server Example ===");
        trace("Starting non-blocking OSC server demonstration...");
        
        // Create async server
        server = new OSCServerAsync(8001, 500); // Port 8001, max 500 queued messages
        
        // Register custom handlers
        setupCustomHandlers();
        
        // Start the server (non-blocking)
        server.start();
        
        trace("");
        trace("Server started on port 8001 (async mode)");
        trace("Main thread continues running...");
        trace("");
        trace("Available OSC commands:");
        trace("  /async/test <string>           - Test async processing");
        trace("  /async/load <int>              - Simulate processing load");
        trace("  /async/stats                   - Get server statistics");
        trace("  /async/shutdown                - Shutdown the server");
        trace("");
        trace("Test with:");
        trace("  node test_osc_client.js 127.0.0.1 8001");
        trace("");
        
        // Main application loop (simulates a GUI or game loop)
        runMainLoop();
        
        // Cleanup
        server.stop();
        trace("Application finished");
    }
    
    static function setupCustomHandlers():Void {
        
        // Async test handler
        server.registerHandler("/async/test", function(msg:OSCMessage):OSCMessage {
            var testMsg = msg.getString(0);
            if (testMsg == null) testMsg = "no message";
            
            trace('Async test received: "$testMsg"');
            
            // Simulate some processing time
            var startTime = haxe.Timer.stamp();
            var endTime = startTime + 0.01; // 10ms of "work"
            while (haxe.Timer.stamp() < endTime) {
                // Busy wait to simulate processing
            }
            
            return new OSCMessage("/async/test/response", [
                OSCType.String('Processed: $testMsg'),
                OSCType.Float(haxe.Timer.stamp())
            ]);
        });
        
        // Load simulation handler
        server.registerHandler("/async/load", function(msg:OSCMessage):OSCMessage {
            var loadLevel = msg.getInt(0);
            if (loadLevel == null) loadLevel = 1;
            
            loadLevel = Std.int(Math.max(1, Math.min(100, loadLevel))); // Clamp 1-100
            
            trace('Simulating load level: $loadLevel');
            
            // Simulate variable processing load
            var workTime = loadLevel * 0.001; // 1-100ms of work
            var startTime = haxe.Timer.stamp();
            var endTime = startTime + workTime;
            
            while (haxe.Timer.stamp() < endTime) {
                // Busy wait to simulate processing
            }
            
            return new OSCMessage("/async/load/response", [
                OSCType.Int(loadLevel),
                OSCType.Float(workTime),
                OSCType.String("Load simulation complete")
            ]);
        });
        
        // Statistics handler
        server.registerHandler("/async/stats", function(msg:OSCMessage):OSCMessage {
            var stats = server.getQueueStats();
            
            trace('Queue Stats - Incoming: ${stats.incoming}, Outgoing: ${stats.outgoing}');
            
            return new OSCMessage("/async/stats/response", [
                OSCType.Int(stats.incoming),
                OSCType.Int(stats.outgoing),
                OSCType.Int(stats.maxSize),
                OSCType.Int(frameCount)
            ]);
        });
        
        // Shutdown handler
        server.registerHandler("/async/shutdown", function(msg:OSCMessage):OSCMessage {
            trace("Shutdown command received - stopping main loop");
            isRunning = false;
            
            return new OSCMessage("/async/shutdown/ack", [
                OSCType.String("Shutting down async server..."),
                OSCType.Int(frameCount)
            ]);
        });
        
        // Batch test handler (for stress testing)
        server.registerHandler("/async/batch", function(msg:OSCMessage):OSCMessage {
            var batchId = msg.getInt(0);
            if (batchId == null) batchId = 0;
            
            return new OSCMessage("/async/batch/response", [
                OSCType.Int(batchId),
                OSCType.Float(haxe.Timer.stamp()),
                OSCType.String("Batch processed")
            ]);
        });
    }
    
    /**
     * Main application loop - simulates a real-time application
     * that needs to remain responsive while processing OSC messages
     */
    static function runMainLoop():Void {
        var targetFPS = 60;
        var frameTime = 1.0 / targetFPS;
        var lastTime = haxe.Timer.stamp();
        var statsInterval = 5.0; // Print stats every 5 seconds
        var lastStatsTime = lastTime;
        
        trace("Starting main loop (60 FPS target)...");
        
        while (isRunning && server.isServerRunning()) {
            var currentTime = haxe.Timer.stamp();
            var deltaTime = currentTime - lastTime;
            
            // Process pending OSC messages (this is non-blocking)
            var messagesProcessed = server.processPendingMessages();
            
            // Simulate main application work
            simulateApplicationWork(deltaTime);
            
            // Update frame counter
            frameCount++;
            
            // Print periodic statistics
            if (currentTime - lastStatsTime >= statsInterval) {
                var stats = server.getQueueStats();
                var fps = frameCount / (currentTime - (lastStatsTime - statsInterval + deltaTime));
                
                trace('=== Stats === Frame: $frameCount, FPS: ${Math.round(fps)}, Messages processed: $messagesProcessed, Queue: ${stats.incoming}/${stats.outgoing}');
                
                lastStatsTime = currentTime;
            }
            
            // Frame rate limiting
            var elapsedFrame = haxe.Timer.stamp() - currentTime;
            var sleepTime = frameTime - elapsedFrame;
            
            if (sleepTime > 0) {
                Sys.sleep(sleepTime);
            }
            
            lastTime = currentTime;
        }
        
        trace('Main loop finished after $frameCount frames');
    }
    
    /**
     * Simulate main application work (rendering, game logic, etc.)
     */
    static function simulateApplicationWork(deltaTime:Float):Void {
        // Simulate some CPU work every frame
        var workTime = 0.002; // 2ms of work per frame
        var startTime = haxe.Timer.stamp();
        var endTime = startTime + workTime;
        
        while (haxe.Timer.stamp() < endTime) {
            // Busy wait to simulate rendering/game logic
        }
        
        // Occasionally do some "heavy" work to test responsiveness
        if (frameCount % 300 == 0) { // Every 5 seconds at 60fps
            trace("Simulating heavy frame processing...");
            var heavyWorkTime = 0.05; // 50ms of heavy work
            var heavyStartTime = haxe.Timer.stamp();
            var heavyEndTime = heavyStartTime + heavyWorkTime;
            
            while (haxe.Timer.stamp() < heavyEndTime) {
                // Busy wait to simulate heavy processing
            }
        }
    }
}
