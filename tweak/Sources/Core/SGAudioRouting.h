#import <AudioToolbox/AudioToolbox.h>
#import <stdbool.h>

// One owner installs Spotify's output hooks. Stages run in this order after its input chain.
enum { SGAudioSpeed, SGAudioEffects, SGAudioHaptics, SGAudioStageCount };
typedef void (*SGAudioConfigure)(AudioUnit output, bool restarted);
// Configure may read the output and build separate processors; it must not set output properties
// synchronously, since that would reenter the owner's property listener.
typedef OSStatus (*SGAudioRender)(void *, AudioUnitRenderActionFlags *, const AudioTimeStamp *, UInt32, UInt32, AudioBufferList *);
typedef void (*SGAudioDisconnect)(AudioUnit output);
bool SGAudioRegister(unsigned stage, SGAudioConfigure configure, SGAudioRender render, SGAudioDisconnect disconnect);
typedef OSStatus (*SGAudioPropertyHandler)(AudioUnit, AudioUnitPropertyID, AudioUnitScope, AudioUnitElement, const void *, UInt32);
bool SGAudioRegisterPropertyHandler(SGAudioPropertyHandler handler);
OSStatus SGAudioOriginalSetProperty(AudioUnit unit, AudioUnitPropertyID property, AudioUnitScope scope, AudioUnitElement element, const void *data, UInt32 size);
