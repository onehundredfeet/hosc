import osc.OSCMessage;
import osc.OSCMessage.OSCType;
import osc.OSCParser;
import osc.OSCBuilder;
import osc.OSCHandlerRegistry;
import haxe.io.Bytes;

/**
 * Unit tests for OSC functionality
 */
class TestOSC {
    
    static function main() {
        trace("=== OSC Unit Tests ===");
        
        var passed = 0;
        var failed = 0;
        
        // Test message creation
        if (testMessageCreation()) passed++; else failed++;
        
        // Test message building and parsing
        if (testBuildAndParse()) passed++; else failed++;
        
        // Test different data types
        if (testDataTypes()) passed++; else failed++;
        
        // Test handler registry
        if (testHandlerRegistry()) passed++; else failed++;
        
        // Test message utilities
        if (testMessageUtils()) passed++; else failed++;
        
        // Test edge cases
        if (testEdgeCases()) passed++; else failed++;
        
        trace('=== Test Results ===');
        trace('Passed: $passed');
        trace('Failed: $failed');
        trace('Total: ${passed + failed}');
        
        if (failed == 0) {
            trace("🎉 All tests passed!");
        } else {
            trace("❌ Some tests failed!");
        }
    }
    
    static function testMessageCreation():Bool {
        trace("Testing message creation...");
        
        try {
            // Test empty message
            var msg1 = new OSCMessage("/test");
            assert(msg1.address == "/test", "Address should be /test");
            assert(msg1.args.length == 0, "Args should be empty");
            
            // Test message with arguments
            var msg2 = new OSCMessage("/test/args", [
                OSCType.Int(42),
                OSCType.Float(3.14),
                OSCType.String("hello")
            ]);
            assert(msg2.args.length == 3, "Should have 3 arguments");
            
            // Test toString
            var str = msg2.toString();
            assert(str.indexOf("/test/args") >= 0, "String should contain address");
            assert(str.indexOf("42") >= 0, "String should contain int value");
            
            trace("✓ Message creation tests passed");
            return true;
        } catch (e:Dynamic) {
            trace('✗ Message creation test failed: $e');
            return false;
        }
    }
    
    static function testBuildAndParse():Bool {
        trace("Testing build and parse round-trip...");
        
        try {
            var original = new OSCMessage("/test/roundtrip", [
                OSCType.Int(123),
                OSCType.Float(45.67),
                OSCType.String("test string")
            ]);
            
            // Build to binary
            var binary = OSCBuilder.buildMessage(original);
            assert(binary.length > 0, "Binary data should not be empty");
            
            // Parse back
            var parsed = OSCParser.parseMessage(binary);
            
            // Verify address
            assert(parsed.address == original.address, "Address should match");
            
            // Verify argument count
            assert(parsed.args.length == original.args.length, "Argument count should match");
            
            // Verify argument values
            assert(parsed.getInt(0) == 123, "First int should be 123");
            assert(Math.abs(parsed.getFloat(1) - 45.67) < 0.001, "Second float should be 45.67");
            assert(parsed.getString(2) == "test string", "Third string should match");
            
            trace("✓ Build and parse tests passed");
            return true;
        } catch (e:Dynamic) {
            trace('✗ Build and parse test failed: $e');
            return false;
        }
    }
    
    static function testDataTypes():Bool {
        trace("Testing different data types...");
        
        try {
            // Test integers
            testIntegerRoundTrip(0);
            testIntegerRoundTrip(42);
            testIntegerRoundTrip(-1000);
            testIntegerRoundTrip(2147483647);  // Max int32
            testIntegerRoundTrip(-2147483648); // Min int32
            
            // Test floats
            testFloatRoundTrip(0.0);
            testFloatRoundTrip(3.14159);
            testFloatRoundTrip(-999.999);
            testFloatRoundTrip(1e10);
            testFloatRoundTrip(1e-10);
            
            // Test strings
            testStringRoundTrip("");
            testStringRoundTrip("hello");
            testStringRoundTrip("Hello World!");
            testStringRoundTrip("Special chars: åäö üß");
            
            // Test blobs
            var blobData = Bytes.ofString("binary data");
            testBlobRoundTrip(blobData);
            
            trace("✓ Data type tests passed");
            return true;
        } catch (e:Dynamic) {
            trace('✗ Data type test failed: $e');
            return false;
        }
    }
    
    static function testIntegerRoundTrip(value:Int):Void {
        var msg = new OSCMessage("/test", [OSCType.Int(value)]);
        var binary = OSCBuilder.buildMessage(msg);
        var parsed = OSCParser.parseMessage(binary);
        assert(parsed.getInt(0) == value, 'Integer $value should round-trip correctly');
    }
    
    static function testFloatRoundTrip(value:Float):Void {
        var msg = new OSCMessage("/test", [OSCType.Float(value)]);
        var binary = OSCBuilder.buildMessage(msg);
        var parsed = OSCParser.parseMessage(binary);
        var parsedValue = parsed.getFloat(0);
        assert(Math.abs(parsedValue - value) < 0.0001, 'Float $value should round-trip correctly (got $parsedValue)');
    }
    
    static function testStringRoundTrip(value:String):Void {
        var msg = new OSCMessage("/test", [OSCType.String(value)]);
        var binary = OSCBuilder.buildMessage(msg);
        var parsed = OSCParser.parseMessage(binary);
        assert(parsed.getString(0) == value, 'String "$value" should round-trip correctly');
    }
    
    static function testBlobRoundTrip(value:Bytes):Void {
        var msg = new OSCMessage("/test", [OSCType.Blob(value)]);
        var binary = OSCBuilder.buildMessage(msg);
        var parsed = OSCParser.parseMessage(binary);
        var parsedBlob = parsed.getBlob(0);
        assert(parsedBlob != null, "Blob should not be null");
        assert(parsedBlob.length == value.length, "Blob length should match");
        assert(parsedBlob.compare(value) == 0, "Blob content should match");
    }
    
    static function testHandlerRegistry():Bool {
        trace("Testing handler registry...");
        
        try {
            var registry = new OSCHandlerRegistry();
            
            // Test handler registration
            var callCount = 0;
            registry.registerHandler("/test", function(msg:OSCMessage):OSCMessage {
                callCount++;
                return new OSCMessage("/response", [OSCType.String("handled")]);
            });
            
            // Test message processing
            var testMsg = new OSCMessage("/test", []);
            var response = registry.processMessage(testMsg);
            
            assert(callCount == 1, "Handler should be called once");
            assert(response != null, "Response should not be null");
            assert(response.address == "/response", "Response address should be /response");
            
            // Test default handler
            var defaultCalled = false;
            registry.setDefaultHandler(function(msg:OSCMessage):OSCMessage {
                defaultCalled = true;
                return new OSCMessage("/default", []);
            });
            
            var unknownMsg = new OSCMessage("/unknown", []);
            var defaultResponse = registry.processMessage(unknownMsg);
            
            assert(defaultCalled, "Default handler should be called");
            assert(defaultResponse.address == "/default", "Default response address should be /default");
            
            // Test registered addresses
            var addresses = registry.getRegisteredAddresses();
            assert(addresses.length == 1, "Should have one registered address");
            assert(addresses[0] == "/test", "Registered address should be /test");
            
            trace("✓ Handler registry tests passed");
            return true;
        } catch (e:Dynamic) {
            trace('✗ Handler registry test failed: $e');
            return false;
        }
    }
    
    static function testMessageUtils():Bool {
        trace("Testing message utility methods...");
        
        try {
            var msg = new OSCMessage("/test", [
                OSCType.Int(42),
                OSCType.Float(3.14),
                OSCType.String("hello"),
                OSCType.Blob(Bytes.ofString("blob"))
            ]);
            
            // Test getters
            assert(msg.getInt(0) == 42, "getInt should return 42");
            assert(msg.getFloat(1) == 3.14, "getFloat should return 3.14");
            assert(msg.getString(2) == "hello", "getString should return hello");
            assert(msg.getBlob(3) != null, "getBlob should not be null");
            
            // Test type conversion
            assert(msg.getFloat(0) == 42.0, "getFloat should convert int to float");
            assert(msg.getInt(1) == 3, "getInt should convert float to int");
            
            // Test bounds checking
            assert(msg.getInt(10) == null, "getInt out of bounds should return null");
            assert(msg.getFloat(-1) == null, "getFloat negative index should return null");
            
            // Test wrong type access
            assert(msg.getString(0) == null, "getString on int should return null");
            assert(msg.getBlob(1) == null, "getBlob on float should return null");
            
            trace("✓ Message utility tests passed");
            return true;
        } catch (e:Dynamic) {
            trace('✗ Message utility test failed: $e');
            return false;
        }
    }
    
    static function testEdgeCases():Bool {
        trace("Testing edge cases...");
        
        try {
            // Test empty address
            var msg1 = new OSCMessage("", []);
            var binary1 = OSCBuilder.buildMessage(msg1);
            var parsed1 = OSCParser.parseMessage(binary1);
            assert(parsed1.address == "", "Empty address should round-trip");
            
            // Test address with special characters
            var msg2 = new OSCMessage("/test/special_chars-123", []);
            var binary2 = OSCBuilder.buildMessage(msg2);
            var parsed2 = OSCParser.parseMessage(binary2);
            assert(parsed2.address == "/test/special_chars-123", "Special chars in address should work");
            
            // Test many arguments
            var manyArgs:Array<OSCType> = [];
            for (i in 0...20) {
                manyArgs.push(OSCType.Int(i));
            }
            var msg3 = new OSCMessage("/many", manyArgs);
            var binary3 = OSCBuilder.buildMessage(msg3);
            var parsed3 = OSCParser.parseMessage(binary3);
            assert(parsed3.args.length == 20, "Should handle many arguments");
            assert(parsed3.getInt(19) == 19, "Last argument should be correct");
            
            trace("✓ Edge case tests passed");
            return true;
        } catch (e:Dynamic) {
            trace('✗ Edge case test failed: $e');
            return false;
        }
    }
    
    static function assert(condition:Bool, message:String):Void {
        if (!condition) {
            throw 'Assertion failed: $message';
        }
    }
}
