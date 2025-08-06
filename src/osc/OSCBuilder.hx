package osc;

import haxe.io.Output;
import haxe.io.Bytes;
import haxe.io.BytesOutput;
import osc.OSCMessage.OSCType;

/**
 * Builder for creating OSC messages in binary format
 */
class OSCBuilder {
    
    /**
     * Build OSC message to binary data
     */
    public static function buildMessage(message:OSCMessage):Bytes {
        var output = new BytesOutput();
        
        // Write address pattern
        writeOSCString(output, message.address);
        
        // Build type tag string
        var typeTag = ",";
        for (arg in message.args) {
            typeTag += switch(arg) {
                case Int(_): "i";
                case Float(_): "f";
                case String(_): "s";
                case Blob(_): "b";
            };
        }
        
        // Write type tag
        writeOSCString(output, typeTag);
        
        // Write arguments
        for (arg in message.args) {
            switch(arg) {
                case Int(value):
                    writeInt32(output, value);
                case Float(value):
                    writeFloat32(output, value);
                case String(value):
                    writeOSCString(output, value);
                case Blob(data):
                    writeOSCBlob(output, data);
            }
        }
        
        return output.getBytes();
    }
    
    /**
     * Write OSC string with null termination and padding
     */
    static function writeOSCString(output:BytesOutput, str:String):Void {
        var bytes = Bytes.ofString(str);
        output.writeFullBytes(bytes, 0, bytes.length);
        output.writeByte(0); // Null terminator
        
        // Add padding to maintain 4-byte alignment
        var totalLength = bytes.length + 1;
        var padding = (4 - (totalLength % 4)) % 4;
        for (i in 0...padding) {
            output.writeByte(0);
        }
    }
    
    /**
     * Write 32-bit big-endian integer
     */
    static function writeInt32(output:BytesOutput, value:Int):Void {
        output.writeByte((value >>> 24) & 0xFF);
        output.writeByte((value >>> 16) & 0xFF);
        output.writeByte((value >>> 8) & 0xFF);
        output.writeByte(value & 0xFF);
    }
    
    /**
     * Write 32-bit big-endian float
     */
    static function writeFloat32(output:BytesOutput, value:Float):Void {
        var bytes = Bytes.alloc(4);
        bytes.setFloat(0, value);
        var intVal = bytes.getInt32(0);
        writeInt32(output, intVal);
    }
    
    /**
     * Write OSC blob with size and padding
     */
    static function writeOSCBlob(output:BytesOutput, data:Bytes):Void {
        writeInt32(output, data.length);
        output.writeFullBytes(data, 0, data.length);
        
        // Add padding to maintain 4-byte alignment
        var padding = (4 - (data.length % 4)) % 4;
        for (i in 0...padding) {
            output.writeByte(0);
        }
    }
}
