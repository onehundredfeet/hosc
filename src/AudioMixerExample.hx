import osc.OSCServer;
import osc.OSCMessage;
import osc.OSCMessage.OSCType;

/**
 * Example: Simple Audio Mixer Control via OSC
 * 
 * This demonstrates how to use the OSC server for a practical application.
 * Simulates a basic audio mixer with volume, pan, and mute controls.
 */
class AudioMixerExample {
    
    static var mixerChannels:Array<MixerChannel> = [];
    static var masterVolume:Float = 0.8;
    static var masterMuted:Bool = false;
    
    static function main() {
        trace("=== Audio Mixer OSC Control Example ===");
        trace("Starting OSC-controlled audio mixer simulation...");
        
        // Initialize mixer channels
        initializeMixer();
        
        // Create OSC server
        var server = new OSCServer(9000);  // Use port 9000 to avoid conflicts
        
        // Register mixer control handlers
        setupMixerHandlers(server);
        
        trace("Mixer initialized with " + mixerChannels.length + " channels");
        trace("OSC Server listening on port 9000");
        trace("");
        trace("Available OSC commands:");
        trace("  /mixer/master/volume <float>     - Set master volume (0.0-1.0)");
        trace("  /mixer/master/mute <int>         - Mute master (0=unmute, 1=mute)");
        trace("  /mixer/channel/N/volume <float>  - Set channel N volume (0.0-1.0)");
        trace("  /mixer/channel/N/pan <float>     - Set channel N pan (-1.0 to 1.0)");
        trace("  /mixer/channel/N/mute <int>      - Mute channel N (0=unmute, 1=mute)");
        trace("  /mixer/status                    - Get mixer status");
        trace("  /mixer/reset                     - Reset all to defaults");
        trace("");
        trace("Example commands to test:");
        trace("  oscsend localhost 9000 /mixer/channel/1/volume f 0.75");
        trace("  oscsend localhost 9000 /mixer/channel/2/pan f -0.5");
        trace("  oscsend localhost 9000 /mixer/master/mute i 1");
        
        // Start the server
        server.start();
    }
    
    static function initializeMixer():Void {
        // Create 8 mixer channels
        for (i in 1...9) {
            mixerChannels.push(new MixerChannel(i));
        }
    }
    
    static function setupMixerHandlers(server:OSCServer):Void {
        
        // Master volume control
        server.registerHandler("/mixer/master/volume", function(msg:OSCMessage):OSCMessage {
            if (msg.args.length > 0) {
                var volume = msg.getFloat(0);
                if (volume != null) {
                    masterVolume = Math.max(0.0, Math.min(1.0, volume));
                    trace('Master volume set to: ${masterVolume}');
                    return new OSCMessage("/mixer/master/volume/confirm", [OSCType.Float(masterVolume)]);
                }
            }
            return new OSCMessage("/mixer/error", [OSCType.String("Invalid master volume value")]);
        });
        
        // Master mute control
        server.registerHandler("/mixer/master/mute", function(msg:OSCMessage):OSCMessage {
            if (msg.args.length > 0) {
                var mute = msg.getInt(0);
                if (mute != null) {
                    masterMuted = mute != 0;
                    trace('Master ${masterMuted ? "muted" : "unmuted"}');
                    return new OSCMessage("/mixer/master/mute/confirm", [OSCType.Int(masterMuted ? 1 : 0)]);
                }
            }
            return new OSCMessage("/mixer/error", [OSCType.String("Invalid master mute value")]);
        });
        
        // Channel volume control (pattern: /mixer/channel/N/volume)
        for (i in 1...9) {
            var channelIndex = i;
            server.registerHandler('/mixer/channel/$channelIndex/volume', function(msg:OSCMessage):OSCMessage {
                if (msg.args.length > 0) {
                    var volume = msg.getFloat(0);
                    if (volume != null) {
                        var channel = getChannel(channelIndex);
                        if (channel != null) {
                            channel.volume = Math.max(0.0, Math.min(1.0, volume));
                            trace('Channel $channelIndex volume set to: ${channel.volume}');
                            return new OSCMessage('/mixer/channel/$channelIndex/volume/confirm', [OSCType.Float(channel.volume)]);
                        }
                    }
                }
                return new OSCMessage("/mixer/error", [OSCType.String('Invalid volume for channel $channelIndex')]);
            });
            
            // Channel pan control
            server.registerHandler('/mixer/channel/$channelIndex/pan', function(msg:OSCMessage):OSCMessage {
                if (msg.args.length > 0) {
                    var pan = msg.getFloat(0);
                    if (pan != null) {
                        var channel = getChannel(channelIndex);
                        if (channel != null) {
                            channel.pan = Math.max(-1.0, Math.min(1.0, pan));
                            trace('Channel $channelIndex pan set to: ${channel.pan}');
                            return new OSCMessage('/mixer/channel/$channelIndex/pan/confirm', [OSCType.Float(channel.pan)]);
                        }
                    }
                }
                return new OSCMessage("/mixer/error", [OSCType.String('Invalid pan for channel $channelIndex')]);
            });
            
            // Channel mute control
            server.registerHandler('/mixer/channel/$channelIndex/mute', function(msg:OSCMessage):OSCMessage {
                if (msg.args.length > 0) {
                    var mute = msg.getInt(0);
                    if (mute != null) {
                        var channel = getChannel(channelIndex);
                        if (channel != null) {
                            channel.muted = mute != 0;
                            trace('Channel $channelIndex ${channel.muted ? "muted" : "unmuted"}');
                            return new OSCMessage('/mixer/channel/$channelIndex/mute/confirm', [OSCType.Int(channel.muted ? 1 : 0)]);
                        }
                    }
                }
                return new OSCMessage("/mixer/error", [OSCType.String('Invalid mute for channel $channelIndex')]);
            });
        }
        
        // Mixer status query
        server.registerHandler("/mixer/status", function(msg:OSCMessage):OSCMessage {
            trace("=== Mixer Status ===");
            trace('Master: Volume=${masterVolume}, Muted=${masterMuted}');
            for (channel in mixerChannels) {
                trace('Channel ${channel.id}: Volume=${channel.volume}, Pan=${channel.pan}, Muted=${channel.muted}');
            }
            
            return new OSCMessage("/mixer/status/response", [
                OSCType.String("Master"),
                OSCType.Float(masterVolume),
                OSCType.Int(masterMuted ? 1 : 0),
                OSCType.String('${mixerChannels.length} channels active')
            ]);
        });
        
        // Reset mixer to defaults
        server.registerHandler("/mixer/reset", function(msg:OSCMessage):OSCMessage {
            trace("Resetting mixer to defaults...");
            masterVolume = 0.8;
            masterMuted = false;
            for (channel in mixerChannels) {
                channel.reset();
            }
            trace("Mixer reset complete");
            return new OSCMessage("/mixer/reset/confirm", [OSCType.String("Mixer reset to defaults")]);
        });
    }
    
    static function getChannel(id:Int):MixerChannel {
        for (channel in mixerChannels) {
            if (channel.id == id) {
                return channel;
            }
        }
        return null;
    }
}

/**
 * Represents a single mixer channel
 */
class MixerChannel {
    public var id:Int;
    public var volume:Float;
    public var pan:Float;
    public var muted:Bool;
    
    public function new(id:Int) {
        this.id = id;
        reset();
    }
    
    public function reset():Void {
        volume = 0.75;  // Default 75% volume
        pan = 0.0;      // Center pan
        muted = false;  // Unmuted
    }
    
    public function getEffectiveVolume():Float {
        return muted ? 0.0 : volume;
    }
    
    public function toString():String {
        return 'Channel $id: Vol=${volume}, Pan=${pan}, Muted=${muted}';
    }
}
