package osc;

import haxe.io.Input;
import haxe.io.Bytes;
import haxe.io.BytesInput;
import osc.OSCMessage.OSCType;

/**
 * Parser for OSC messages from binary data
 */
class OSCParser {
    
    /**
     * Parse OSC message from binary data
     */
    public static function parseMessage(data:Bytes):OSCMessage {
        var input = new BytesInput(data);
        
        // Read address pattern (null-terminated string with padding)
        var address = readOSCString(input);
        
        // Read type tag string (starts with ',')
        var typeTag = readOSCString(input);
        
        if (typeTag.charAt(0) != ',') {
            throw "Invalid OSC message: type tag must start with ','";
        }
        
        // Parse arguments based on type tags
        var args:Array<OSCType> = [];
        var types = typeTag.substr(1); // Remove the leading ','
        
        for (i in 0...types.length) {
            var type = types.charAt(i);
            switch (type) {
                case 'i': // 32-bit integer
                    args.push(OSCType.Int(readInt32(input)));
                case 'f': // 32-bit float
                    args.push(OSCType.Float(readFloat32(input)));
                case 's': // string
                    args.push(OSCType.String(readOSCString(input)));
                case 'b': // blob
                    args.push(OSCType.Blob(readOSCBlob(input)));
                default:
                    trace('Warning: Unsupported OSC type: $type');
            }
        }
        
        return new OSCMessage(address, args);
    }
    
    /**
     * Read a null-terminated string from the input
     */
    static function readOSCString(input:Input):String {
        var bytes:Array<Int> = [];
        var byte:Int;
        
        // Read until null terminator
        while ((byte = input.readByte()) != 0) {
            bytes.push(byte);
        }
        
        // Skip padding to 4-byte boundary
        var padding = (4 - (bytes.length + 1) % 4) % 4;
        for (i in 0...padding) {
            input.readByte();
        }
        
        // Convert bytes to string
        var resultBytes = Bytes.alloc(bytes.length);
        for (i in 0...bytes.length) {
            resultBytes.set(i, bytes[i]);
        }
        return resultBytes.toString();
    }
    
    /**
     * Read 32-bit big-endian integer
     */
    static function readInt32(input:BytesInput):Int {
        var b1 = input.readByte();
        var b2 = input.readByte();
        var b3 = input.readByte();
        var b4 = input.readByte();
        return (b1 << 24) | (b2 << 16) | (b3 << 8) | b4;
    }
    
    /**
     * Read 32-bit big-endian float
     */
    static function readFloat32(input:BytesInput):Float {
        var intVal = readInt32(input);
        // Convert integer bits to float
        var bytes = Bytes.alloc(4);
        bytes.setInt32(0, intVal);
        return bytes.getFloat(0);
    }
    
    /**
     * Read OSC blob (size + data with padding)
     */
    static function readOSCBlob(input:BytesInput):Bytes {
        var size = readInt32(input);
        var data = Bytes.alloc(size);
        input.readFullBytes(data, 0, size);
        
        // Read padding bytes to maintain 4-byte alignment
        var padding = (4 - (size % 4)) % 4;
        for (i in 0...padding) {
            input.readByte();
        }
        
        return data;
    }
}
