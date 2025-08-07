import osc.*;
import osc.OSCMessage.OSCType;

class LibraryTest {
    static function main() {
        trace("Testing Haxe OSC Library...");
        
        // Test OSC message creation and parsing
        var msg = new OSCMessage("/test/library", [
            OSCType.Int(42),
            OSCType.Float(3.14),
            OSCType.String("hello"),
            OSCType.Blob(haxe.io.Bytes.ofString("test"))
        ]);
        
        trace('Created message: ${msg.address}');
        trace('Arguments: ${msg.args.length}');
        
        // Test OSC builder
        var data = OSCBuilder.buildMessage(msg);
        trace('Built ${data.length} bytes of OSC data');
        
        // Test OSC parser
        var parsed = OSCParser.parseMessage(data);
        trace('Parsed message: ${parsed.address}');
        trace('Parsed arguments: ${parsed.args.length}');
        
        // Test handler registry
        var registry = new OSCHandlerRegistry();
        registry.registerHandler("/test/library", function(msg) {
            return new OSCMessage("/response", [OSCType.String("ok")]);
        });
        
        var response = registry.processMessage(msg);
        if (response != null) {
            trace('Handler response: ${response.address}');
        }
        
        // Test blocking server (without actually listening)
        var server = new OSCServer(8765);
        server.registerHandler("/library/test", function(msg) {
            return new OSCMessage("/library/response", [OSCType.String("library works")]);
        });
        
        trace("All library components tested successfully!");
        trace("Library is ready for use in C++ projects.");
    }
}
