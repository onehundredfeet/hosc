package osc;

/**
 * Represents different OSC data types
 */
enum OSCType {
    Int(value:Int);
    Float(value:Float);
    String(value:String);
    Blob(value:haxe.io.Bytes);
}

/**
 * Type alias for OSC message handler functions
 */
typedef OSCHandler = OSCMessage -> OSCMessage;

/**
 * Represents an OSC message with address and arguments
 */
class OSCMessage {
    public var address:String;
    public var args:Array<OSCType>;
    
    public function new(address:String, args:Array<OSCType> = null) {
        this.address = address;
        this.args = args != null ? args : [];
    }
    
    /**
     * Convert message to string representation for debugging
     */
    public function toString():String {
        var argsStr = args.map(function(arg) {
            return switch(arg) {
                case Int(v): 'i:$v';
                case Float(v): 'f:$v';
                case String(v): 's:"$v"';
                case Blob(v): 'b:[${v.length} bytes]';
            }
        }).join(", ");
        
        return '$address($argsStr)';
    }
    
    /**
     * Get argument at index as specific type
     */
    public function getInt(index:Int):Null<Int> {
        if (index >= 0 && index < args.length) {
            return switch(args[index]) {
                case Int(v): v;
                case Float(v): Std.int(v);
                default: null;
            }
        }
        return null;
    }
    
    public function getFloat(index:Int):Null<Float> {
        if (index >= 0 && index < args.length) {
            return switch(args[index]) {
                case Float(v): v;
                case Int(v): v;
                default: null;
            }
        }
        return null;
    }
    
    public function getString(index:Int):Null<String> {
        if (index >= 0 && index < args.length) {
            return switch(args[index]) {
                case String(v): v;
                default: null;
            }
        }
        return null;
    }
    
    public function getBlob(index:Int):Null<haxe.io.Bytes> {
        if (index >= 0 && index < args.length) {
            return switch(args[index]) {
                case Blob(v): v;
                default: null;
            }
        }
        return null;
    }
}
