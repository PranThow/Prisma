#import "SGAudioRouting.h"
#import "SGRebind.h"
#import "SGLog.h"
#import <pthread.h>

typedef struct {
    SGAudioConfigure configure;
    SGAudioRender render;
    SGAudioDisconnect disconnect;
} Stage;
static Stage stages[SGAudioStageCount];
static SGAudioPropertyHandler propertyHandler;
static OSStatus (*originalStart)(AudioUnit);
static OSStatus (*originalStop)(AudioUnit);
static OSStatus (*originalDispose)(AudioComponentInstance);
static OSStatus (*originalSet)(AudioUnit, AudioUnitPropertyID, AudioUnitScope, AudioUnitElement, const void *, UInt32);
static pthread_mutex_t control = PTHREAD_MUTEX_INITIALIZER;

enum { kOutputs = 16 };
typedef struct { AudioUnit unit; bool started; } Output;
static Output outputs[kOutputs]; // protected by control; render receives a stable slot
static pthread_mutex_t renderLocks[kOutputs];

static bool remoteIO(AudioUnit unit) {
    AudioComponentDescription d = {0};
    return unit && AudioComponentGetDescription(AudioComponentInstanceGetComponent(unit), &d) == noErr &&
        d.componentType == kAudioUnitType_Output && d.componentSubType == kAudioUnitSubType_RemoteIO;
}
static Output *find(AudioUnit unit, bool create) {
    Output *empty = NULL;
    for (unsigned i = 0; i < kOutputs; i++) {
        if (outputs[i].unit == unit) return &outputs[i];
        if (!outputs[i].unit && !empty) empty = &outputs[i];
    }
    if (create && empty) empty->unit = unit;
    return create ? empty : NULL;
}
static OSStatus rendered(void *context, AudioUnitRenderActionFlags *flags, const AudioTimeStamp *time,
                         UInt32 bus, UInt32 frames, AudioBufferList *data) {
    if (!flags || !data || !frames || bus || !(*flags & kAudioUnitRenderAction_PostRender) ||
        (*flags & kAudioUnitRenderAction_PostRenderError)) return noErr;
    Output *output = context;
    pthread_mutex_t *renderLock = &renderLocks[output - outputs];
    if (pthread_mutex_trylock(renderLock)) return noErr; // never wait on the audio thread
    if (output->started) {
        for (unsigned i = 0; i < SGAudioStageCount; i++) if (stages[i].render) stages[i].render(output->unit, flags, time, bus, frames, data);
    }
    pthread_mutex_unlock(renderLock);
    return noErr;
}
static void changed(void *context, AudioUnit unit, AudioUnitPropertyID property, AudioUnitScope scope, AudioUnitElement element) {
    if (element || property != kAudioUnitProperty_StreamFormat) return;
    pthread_mutex_lock(&control);
    Output *output = find(unit, false);
    if (output) {
        pthread_mutex_lock(&renderLocks[output - outputs]);
        for (unsigned i = 0; i < SGAudioStageCount; i++) if (stages[i].configure) stages[i].configure(unit, false);
        pthread_mutex_unlock(&renderLocks[output - outputs]);
    }
    pthread_mutex_unlock(&control);
}
static OSStatus start(AudioUnit unit) {
    if (!remoteIO(unit)) return originalStart(unit);
    pthread_mutex_lock(&control);
    Output *output = find(unit, true);
    if (output) {
        pthread_mutex_lock(&renderLocks[output - outputs]);
        output->started = true;
        AudioUnitRemoveRenderNotify(unit, rendered, output);
        AudioUnitRemovePropertyListenerWithUserData(unit, kAudioUnitProperty_StreamFormat, changed, output);
        for (unsigned i = 0; i < SGAudioStageCount; i++) if (stages[i].configure) stages[i].configure(unit, true);
        AudioUnitAddPropertyListener(unit, kAudioUnitProperty_StreamFormat, changed, output);
        AudioUnitAddRenderNotify(unit, rendered, output);
        pthread_mutex_unlock(&renderLocks[output - outputs]);
    }
    pthread_mutex_unlock(&control);
    OSStatus status = originalStart(unit);
    if (status != noErr && output) {
        pthread_mutex_lock(&control);
        pthread_mutex_lock(&renderLocks[output - outputs]);
        if (output->unit == unit) output->started = false;
        pthread_mutex_unlock(&renderLocks[output - outputs]);
        pthread_mutex_unlock(&control);
    }
    return status;
}
static void stopped(AudioUnit unit, bool disposed) {
    pthread_mutex_lock(&control);
    Output *output = find(unit, false);
    if (output) {
        pthread_mutex_lock(&renderLocks[output - outputs]);
        output->started = false;
        if (disposed) {
            AudioUnitRemoveRenderNotify(unit, rendered, output);
            AudioUnitRemovePropertyListenerWithUserData(unit, kAudioUnitProperty_StreamFormat, changed, output);
            for (unsigned i = 0; i < SGAudioStageCount; i++) if (stages[i].disconnect) stages[i].disconnect(unit);
            *output = (Output){0};
        }
        pthread_mutex_unlock(&renderLocks[output - outputs]);
    }
    pthread_mutex_unlock(&control);
}
static OSStatus stop(AudioUnit unit) {
    OSStatus status = originalStop(unit);
    if (!status) stopped(unit, false);
    return status;
}
static OSStatus dispose(AudioComponentInstance unit) {
    if (remoteIO(unit)) {
        if (originalStop) originalStop(unit);
        stopped(unit, true);
    } else {
        // A mixer/converter can be disposed before its output. Input owners must detach it first.
        pthread_mutex_lock(&control);
        for (unsigned i = 0; i < SGAudioStageCount; i++) if (stages[i].disconnect) stages[i].disconnect(unit);
        pthread_mutex_unlock(&control);
    }
    return originalDispose(unit);
}
OSStatus SGAudioOriginalSetProperty(AudioUnit unit, AudioUnitPropertyID property, AudioUnitScope scope, AudioUnitElement element, const void *data, UInt32 size) {
    return originalSet ? originalSet(unit, property, scope, element, data, size) : AudioUnitSetProperty(unit, property, scope, element, data, size);
}
static OSStatus set(AudioUnit unit, AudioUnitPropertyID property, AudioUnitScope scope, AudioUnitElement element, const void *data, UInt32 size) {
    return propertyHandler ? propertyHandler(unit, property, scope, element, data, size) : SGAudioOriginalSetProperty(unit, property, scope, element, data, size);
}
static bool install(void) {
    static bool available;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        for (unsigned i = 0; i < kOutputs; i++) pthread_mutex_init(&renderLocks[i], NULL);
        // Require disposal/stop hooks before retaining unit state.
        bool safe = SGRebindImport("AudioComponentInstanceDispose", dispose, (void **)&originalDispose) && originalDispose;
        safe = SGRebindImport("AudioOutputUnitStop", stop, (void **)&originalStop) && originalStop && safe;
        SGRebindImport("AudioUnitSetProperty", set, (void **)&originalSet);
        if (safe) available = SGRebindImport("AudioOutputUnitStart", start, (void **)&originalStart) && originalStart;
        if (!available) SGLog(@"audio: output lifecycle imports unavailable; processing disabled");
    });
    return available;
}
bool SGAudioRegister(unsigned stage, SGAudioConfigure configure, SGAudioRender render, SGAudioDisconnect disconnect) {
    if (stage >= SGAudioStageCount || !install()) return false;
    stages[stage] = (Stage){configure, render, disconnect};
    return true;
}
bool SGAudioRegisterPropertyHandler(SGAudioPropertyHandler handler) {
    if (!install() || !originalSet) return false;
    propertyHandler = handler;
    return true;
}
