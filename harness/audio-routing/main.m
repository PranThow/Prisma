#import <Foundation/Foundation.h>
#import <AudioToolbox/AudioToolbox.h>
#import <assert.h>
#import "Core/SGAudioRouting.h"

typedef struct {
    double rate;
    AURenderCallback callback;
    void *context;
    AudioUnitPropertyListenerProc changed;
    void *changeContext;
    unsigned configured, renders, disposed, step;
} Fake;
static OSStatus (*startHook)(AudioUnit), (*stopHook)(AudioUnit), (*disposeHook)(AudioComponentInstance);
static OSStatus original(AudioUnit unit) { return noErr; }
static OSStatus originalDispose(AudioComponentInstance unit) { ((Fake *)unit)->disposed++; return noErr; }
static OSStatus originalSet(AudioUnit u, AudioUnitPropertyID p, AudioUnitScope s, AudioUnitElement e, const void *d, UInt32 n) { return noErr; }
BOOL SGRebindImport(const char *name, void *replacement, void **into) {
    if (!strcmp(name, "AudioOutputUnitStart")) { startHook = replacement; *into = original; }
    else if (!strcmp(name, "AudioOutputUnitStop")) { stopHook = replacement; *into = original; }
    else if (!strcmp(name, "AudioComponentInstanceDispose")) { disposeHook = replacement; *into = originalDispose; }
    else if (!strcmp(name, "AudioUnitSetProperty")) *into = originalSet;
    else return NO;
    return YES;
}
AudioComponent AudioComponentInstanceGetComponent(AudioComponentInstance unit) { return (AudioComponent)unit; }
OSStatus AudioComponentGetDescription(AudioComponent component, AudioComponentDescription *description) {
    *description = (AudioComponentDescription){.componentType = kAudioUnitType_Output, .componentSubType = kAudioUnitSubType_RemoteIO};
    return noErr;
}
OSStatus AudioUnitAddRenderNotify(AudioUnit unit, AURenderCallback callback, void *context) { ((Fake *)unit)->callback = callback; ((Fake *)unit)->context = context; return noErr; }
OSStatus AudioUnitRemoveRenderNotify(AudioUnit unit, AURenderCallback callback, void *context) { ((Fake *)unit)->callback = NULL; return noErr; }
OSStatus AudioUnitAddPropertyListener(AudioUnit unit, AudioUnitPropertyID property, AudioUnitPropertyListenerProc callback, void *context) {
    ((Fake *)unit)->changed = callback; ((Fake *)unit)->changeContext = context; return noErr;
}
OSStatus AudioUnitRemovePropertyListenerWithUserData(AudioUnit unit, AudioUnitPropertyID property, AudioUnitPropertyListenerProc callback, void *context) { ((Fake *)unit)->changed = NULL; return noErr; }
static Fake *nested;
static void render(Fake *unit);
static void configure(AudioUnit unit, bool restart) { Fake *fake = (Fake *)unit; assert(fake->rate == 44100 || fake->rate == 48000); fake->configured++; }
static void disconnect(AudioUnit unit) { ((Fake *)unit)->configured = 0; }
static OSStatus speed(void *unit, AudioUnitRenderActionFlags *f, const AudioTimeStamp *t, UInt32 b, UInt32 n, AudioBufferList *d) {
    assert(((Fake *)unit)->step++ == 0);
    if (nested) { Fake *other = nested; nested = NULL; render(other); }
    return noErr;
}
static OSStatus effects(void *unit, AudioUnitRenderActionFlags *f, const AudioTimeStamp *t, UInt32 b, UInt32 n, AudioBufferList *d) { assert(((Fake *)unit)->step++ == 1); return noErr; }
static OSStatus haptics(void *unit, AudioUnitRenderActionFlags *f, const AudioTimeStamp *t, UInt32 b, UInt32 n, AudioBufferList *d) { assert(((Fake *)unit)->step++ == 2); ((Fake *)unit)->renders++; return noErr; }
static void render(Fake *unit) {
    AudioUnitRenderActionFlags flags = kAudioUnitRenderAction_PostRender;
    AudioTimeStamp time = {0}; float samples[128] = {0};
    AudioBufferList data = {1, {{1, sizeof samples, samples}}};
    unit->step = 0;
    assert(unit->callback(unit->context, &flags, &time, 0, 128, &data) == noErr);
}
int main(void) {
    @autoreleasepool {
        assert(SGAudioRegister(SGAudioSpeed, configure, speed, disconnect));
        assert(SGAudioRegister(SGAudioEffects, configure, effects, NULL));
        assert(SGAudioRegister(SGAudioHaptics, configure, haptics, NULL));
        Fake a = {.rate = 44100}, b = {.rate = 48000};
        assert(startHook((AudioUnit)&a) == noErr && startHook((AudioUnit)&b) == noErr);
        render(&a); render(&b); render(&a);
        assert(a.renders == 2 && b.renders == 1);
        assert(a.configured == 3 && b.configured == 3);
        a.rate = 48000;
        a.changed(a.changeContext, (AudioUnit)&a, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Output, 0);
        assert(a.configured == 6 && b.configured == 3);
        stopHook((AudioUnit)&a); render(&a); assert(a.step == 0 && a.renders == 2);
        startHook((AudioUnit)&a); render(&a); assert(a.renders == 3);
        nested = &b; render(&a); assert(a.renders == 4 && b.renders == 2);
        disposeHook((AudioUnit)&a); assert(!a.callback && !a.changed && a.disposed == 1);
        render(&b); assert(b.renders == 3);
        disposeHook((AudioUnit)&b);
        puts("audio owner: output isolation, stage order, format, stop/restart and disposal passed");
    }
}
