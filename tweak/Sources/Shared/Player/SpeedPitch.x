// One source clock and processing units per RemoteIO output. The owner orders post-render stages.
#import <AudioToolbox/AudioToolbox.h>
#import <pthread.h>
#import <stdatomic.h>
#import "Core/SGCore.h"
#import "Core/SGAudioRouting.h"
#import "Headers/SPTPlayer.h"
#import "SpeedPitch.h"
#import "SGTimePitch.h"

typedef struct {
    AudioUnit output, source;
    UInt32 bus, chunk;
    Float64 time;
    AudioStreamBasicDescription client, hardware;
    SGTimePitch *pull, *inPlace;
    BOOL engaged;
    float scratch[kSGTimePitchMaxChannels][kSGTimePitchMaxFrames];
} Source;
static Source sources[16];
static pthread_mutex_t lock = PTHREAD_MUTEX_INITIALIZER;
static pthread_mutex_t sourceLocks[16];
static float speed = 1, semitones;
static BOOL coupled = YES, available;
static atomic_uint speedBits;
static NSUInteger change;

static Source *find(AudioUnit output, BOOL create) {
    Source *empty = NULL;
    for (unsigned i = 0; i < 16; i++) {
        if (sources[i].output == output) return &sources[i];
        if (!sources[i].output && !empty) empty = &sources[i];
    }
    if (create && empty) { empty->output = output; empty->chunk = 1024; }
    return create ? empty : NULL;
}
static void silence(AudioBufferList *data) {
    if (!data) return;
    for (UInt32 b = 0; b < data->mNumberBuffers; b++) if (data->mBuffers[b].mData) memset(data->mBuffers[b].mData, 0, data->mBuffers[b].mDataByteSize);
}
static OSStatus pullSource(void *context, UInt32 frames, AudioBufferList *data) {
    Source *chain = context;
    enum { kMaxBuffers = 8 };
    if (!chain || !chain->source) { silence(data); return noErr; }
    if (!frames || frames > kSGTimePitchMaxFrames * 4 || !data || data->mNumberBuffers > kMaxBuffers) return kAudioUnitErr_TooManyFramesToProcess;
    UInt32 bytes[kMaxBuffers];
    for (UInt32 b = 0; b < data->mNumberBuffers; b++) {
        if (!data->mBuffers[b].mData || data->mBuffers[b].mDataByteSize % frames) return kAudioUnitErr_InvalidPropertyValue;
        bytes[b] = data->mBuffers[b].mDataByteSize / frames;
    }
    for (UInt32 done = 0; done < frames;) {
        UInt32 count = MIN(chain->chunk, frames - done);
        struct { AudioBufferList list; AudioBuffer more[kMaxBuffers - 1]; } part;
        part.list.mNumberBuffers = data->mNumberBuffers;
        for (UInt32 b = 0; b < data->mNumberBuffers; b++) part.list.mBuffers[b] = (AudioBuffer){data->mBuffers[b].mNumberChannels, count * bytes[b], (char *)data->mBuffers[b].mData + done * bytes[b]};
        AudioTimeStamp stamp = {.mSampleTime = chain->time, .mFlags = kAudioTimeStampSampleTimeValid};
        AudioUnitRenderActionFlags flags = 0;
        OSStatus status = AudioUnitRender(chain->source, &flags, &stamp, chain->bus, count, &part.list);
        chain->time += count;
        if (status) return status;
        done += count;
    }
    return noErr;
}
static BOOL fits(const AudioBufferList *data, UInt32 frames, SGTimePitch *unit) {
    if (!unit || data->mNumberBuffers != SGTimePitchChannels(unit) || frames > kSGTimePitchMaxFrames) return NO;
    for (UInt32 b = 0; b < data->mNumberBuffers; b++) if (!data->mBuffers[b].mData || data->mBuffers[b].mDataByteSize < frames * sizeof(float)) return NO;
    return YES;
}
static OSStatus feed(void *context, AudioUnitRenderActionFlags *flags, const AudioTimeStamp *stamp, UInt32 bus, UInt32 frames, AudioBufferList *data) {
    if (!frames || !data) return noErr;
    Source *chain = context;
    pthread_mutex_t *sourceLock = &sourceLocks[chain - sources];
    if (pthread_mutex_trylock(sourceLock)) { silence(data); *flags |= kAudioUnitRenderAction_OutputIsSilence; return noErr; }
    OSStatus status;
    if (chain->engaged && fits(data, frames, chain->pull)) {
        status = SGTimePitchRender(chain->pull, frames, data);
        // Failed processors may already have consumed input; never pull it a second time.
        if (status) { silence(data); *flags |= kAudioUnitRenderAction_OutputIsSilence; }
    } else status = pullSource(chain, frames, data);
    pthread_mutex_unlock(sourceLock);
    return status;
}
static inline float readSample(const void *data, UInt32 index, UInt32 bytes, BOOL isFloat, UInt32 fraction) {
    if (bytes == 4) {
        if (isFloat) return ((const float *)data)[index];
        int32_t value = ((const int32_t *)data)[index];
        return fraction ? (float)((double)value / (double)(1u << fraction)) : (float)(value / 2147483648.0);
    }
    return ((const int16_t *)data)[index] / 32768.0f;
}

static inline void writeSample(void *data, UInt32 index, float value, UInt32 bytes, BOOL isFloat, UInt32 fraction) {
    if (bytes == 4 && isFloat) {
        ((float *)data)[index] = value;
        return;
    }
    value = fmaxf(-1, fminf(value, 1));
    if (bytes == 4) {
        double scale = fraction ? (double)(1u << fraction) : 2147483647.0;
        ((int32_t *)data)[index] = (int32_t)(value * scale);
    } else {
        ((int16_t *)data)[index] = (int16_t)(value * 32767);
    }
}

static void shiftInPlace(Source *chain, SGTimePitch *unit, AudioUnitRenderActionFlags *flags, UInt32 frames, AudioBufferList *data) {
    UInt32 formatFlags = chain->hardware.mFormatFlags;
    UInt32 bytes = chain->hardware.mBitsPerChannel / 8;
    UInt32 channels = SGTimePitchChannels(unit);
    BOOL isFloat = (formatFlags & kAudioFormatFlagIsFloat) != 0;
    BOOL split = (formatFlags & kAudioFormatFlagIsNonInterleaved) != 0;
    UInt32 fraction = (formatFlags & kLinearPCMFormatFlagsSampleFractionMask) >> kLinearPCMFormatFlagsSampleFractionShift;
    if (frames > kSGTimePitchMaxFrames || (bytes != 2 && bytes != 4)) return;
    if (split ? data->mNumberBuffers != channels : data->mNumberBuffers != 1 || data->mBuffers[0].mNumberChannels != channels) return;
    for (UInt32 b = 0; b < data->mNumberBuffers; b++) {
        if (!data->mBuffers[b].mData || data->mBuffers[b].mDataByteSize < frames * bytes * (split ? 1 : channels)) return;
    }
    // Silence still goes through, so the sound the unit holds plays out rather than coming back later.
    BOOL silent = (*flags & kAudioUnitRenderAction_OutputIsSilence) != 0;

    float *lanes[kSGTimePitchMaxChannels];
    BOOL direct = split && isFloat && bytes == 4 && !silent;
    for (UInt32 c = 0; c < channels; c++) {
        if (direct) {
            lanes[c] = data->mBuffers[c].mData;
            continue;
        }
        lanes[c] = chain->scratch[c];
        const void *source = data->mBuffers[split ? c : 0].mData;
        for (UInt32 i = 0; i < frames; i++) {
            lanes[c][i] = silent ? 0 : readSample(source, split ? i : i * channels + c, bytes, isFloat, fraction);
        }
    }
    if (!SGTimePitchProcess(unit, lanes, frames) || direct) return;
    for (UInt32 c = 0; c < channels; c++) {
        void *target = data->mBuffers[split ? c : 0].mData;
        for (UInt32 i = 0; i < frames; i++) writeSample(target, split ? i : i * channels + c, lanes[c][i], bytes, isFloat, fraction);
    }
    *flags &= ~kAudioUnitRenderAction_OutputIsSilence;
}


static OSStatus rendered(void *output, AudioUnitRenderActionFlags *flags, const AudioTimeStamp *stamp, UInt32 bus, UInt32 frames, AudioBufferList *data) {
    if (!data || !frames || pthread_mutex_trylock(&lock)) return noErr;
    Source *chain = find(output, NO);
    pthread_mutex_unlock(&lock);
    if (!chain) return noErr;
    pthread_mutex_t *sourceLock = &sourceLocks[chain - sources];
    if (pthread_mutex_trylock(sourceLock)) return noErr;
    if (chain && !chain->source && chain->engaged && chain->inPlace) shiftInPlace(chain, chain->inPlace, flags, frames, data);
    pthread_mutex_unlock(sourceLock);
    return noErr;
}
static BOOL readFormat(AudioUnit output, AudioUnitScope scope, AudioStreamBasicDescription *format) {
    UInt32 size = sizeof *format;
    *format = (AudioStreamBasicDescription){0};
    return !AudioUnitGetProperty(output, kAudioUnitProperty_StreamFormat, scope, 0, format, &size) &&
        format->mFormatID == kAudioFormatLinearPCM && isfinite(format->mSampleRate) && format->mSampleRate > 0 &&
        format->mChannelsPerFrame >= 1 && format->mChannelsPerFrame <= kSGTimePitchMaxChannels;
}
static void destroyUnits(Source *chain) {
    chain->engaged = NO;
    SGTimePitchDestroy(chain->pull); SGTimePitchDestroy(chain->inPlace);
    chain->pull = chain->inPlace = NULL;
}
static void build(Source *chain) {
    destroyUnits(chain);
    AudioStreamBasicDescription *format = chain->source ? &chain->client : &chain->hardware;
    if (format->mSampleRate <= 0 || !format->mChannelsPerFrame || format->mChannelsPerFrame > kSGTimePitchMaxChannels) return;
    BOOL canonical = (format->mFormatFlags & kAudioFormatFlagIsFloat) && (format->mFormatFlags & kAudioFormatFlagIsNonInterleaved) && format->mBitsPerChannel == 32;
    if (chain->source && !canonical) return;
    SGTimePitch *unit = chain->source && coupled
        ? SGTimePitchCreateVarispeed(format->mSampleRate, format->mChannelsPerFrame, pullSource, chain)
        : SGTimePitchCreate(format->mSampleRate, format->mChannelsPerFrame, chain->source ? pullSource : NULL, chain);
    if (chain->source) chain->pull = unit; else chain->inPlace = unit;
    if (!unit) return;
    SGTimePitchSetRate(unit, chain->source ? speed : 1);
    SGTimePitchSetSemitones(unit, coupled ? 0 : semitones);
    chain->engaged = (chain->source && speed != 1) || (!coupled && semitones != 0);
}
static void configure(AudioUnit output, bool restarted) {
    pthread_mutex_lock(&lock);
    Source *chain = find(output, YES);
    if (chain) {
        pthread_mutex_lock(&sourceLocks[chain - sources]);
        AudioStreamBasicDescription client, hardware;
        readFormat(output, kAudioUnitScope_Input, &client);
        readFormat(output, kAudioUnitScope_Output, &hardware);
        BOOL different = memcmp(&client, &chain->client, sizeof client) || memcmp(&hardware, &chain->hardware, sizeof hardware);
        chain->client = client; chain->hardware = hardware;
        if (different || restarted || (!chain->pull && !chain->inPlace)) build(chain);
        pthread_mutex_unlock(&sourceLocks[chain - sources]);
    }
    pthread_mutex_unlock(&lock);
}
static void disconnect(AudioUnit output) {
    pthread_mutex_lock(&lock);
    for (unsigned i = 0; i < 16; i++) {
        Source *chain = &sources[i];
        if (chain->output != output && chain->source != output) continue;
        pthread_mutex_lock(&sourceLocks[i]);
        destroyUnits(chain);
        if (chain->output == output) *chain = (Source){0};
        else { chain->source = NULL; chain->time = 0; }
        pthread_mutex_unlock(&sourceLocks[i]);
    }
    pthread_mutex_unlock(&lock);
}
static BOOL remoteIO(AudioUnit output) {
    AudioComponentDescription d = {0};
    return output && !AudioComponentGetDescription(AudioComponentInstanceGetComponent(output), &d) && d.componentType == kAudioUnitType_Output && d.componentSubType == kAudioUnitSubType_RemoteIO;
}
static OSStatus setProperty(AudioUnit output, AudioUnitPropertyID property, AudioUnitScope scope, AudioUnitElement element, const void *data, UInt32 size) {
    if (property == kAudioUnitProperty_MaximumFramesPerSlice && data && size >= sizeof(UInt32)) {
        OSStatus status = SGAudioOriginalSetProperty(output, property, scope, element, data, size);
        if (!status) {
            UInt32 maximum = MAX(1u, MIN(*(const UInt32 *)data, (UInt32)kSGTimePitchMaxFrames));
            pthread_mutex_lock(&lock);
            for (unsigned i = 0; i < 16; i++) if (sources[i].source == output) {
                pthread_mutex_lock(&sourceLocks[i]); sources[i].chunk = maximum; pthread_mutex_unlock(&sourceLocks[i]);
            }
            pthread_mutex_unlock(&lock);
        }
        return status;
    }
    if (property == kAudioUnitProperty_SetRenderCallback && scope == kAudioUnitScope_Input && !element && remoteIO(output)) {
        pthread_mutex_lock(&lock);
        Source *chain = find(output, NO);
        if (chain) {
            pthread_mutex_lock(&sourceLocks[chain - sources]);
            destroyUnits(chain); chain->source = NULL; chain->time = 0;
            pthread_mutex_unlock(&sourceLocks[chain - sources]);
        }
        pthread_mutex_unlock(&lock);
        OSStatus status = SGAudioOriginalSetProperty(output, property, scope, element, data, size);
        if (!status) configure(output, false);
        return status;
    }
    if (property == kAudioUnitProperty_StreamFormat && scope == kAudioUnitScope_Input && !element && data && size >= sizeof(AudioStreamBasicDescription) && remoteIO(output)) {
        pthread_mutex_lock(&lock);
        Source *chain = find(output, NO);
        AudioUnit source = chain ? chain->source : NULL;
        UInt32 bus = chain ? chain->bus : 0;
        pthread_mutex_unlock(&lock);
        AudioStreamBasicDescription actual = {0}, requested = *(const AudioStreamBasicDescription *)data;
        UInt32 length = sizeof actual;
        if (source && !AudioUnitGetProperty(source, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Output, bus, &actual, &length) &&
            actual.mFormatID == kAudioFormatLinearPCM && requested.mFormatID == kAudioFormatLinearPCM &&
            isfinite(actual.mSampleRate) && actual.mSampleRate > 0 && actual.mChannelsPerFrame == requested.mChannelsPerFrame) {
            requested.mSampleRate = actual.mSampleRate;
            return SGAudioOriginalSetProperty(output, property, scope, element, &requested, sizeof requested);
        }
    }
    if (property != kAudioUnitProperty_MakeConnection || scope != kAudioUnitScope_Input || element || !data || size < sizeof(AudioUnitConnection) || !remoteIO(output)) return SGAudioOriginalSetProperty(output, property, scope, element, data, size);
    const AudioUnitConnection *connection = data;
    pthread_mutex_lock(&lock);
    Source *chain = find(output, YES);
    if (!chain) { pthread_mutex_unlock(&lock); return SGAudioOriginalSetProperty(output, property, scope, element, data, size); }
    pthread_mutex_lock(&sourceLocks[chain - sources]);
    destroyUnits(chain);
    if (chain->source != connection->sourceAudioUnit || chain->bus != connection->sourceOutputNumber) chain->time = 0;
    chain->source = connection->sourceAudioUnit; chain->bus = connection->sourceOutputNumber;
    if (chain->source) {
        UInt32 maximum = 1024, length = sizeof maximum;
        AudioUnitGetProperty(chain->source, kAudioUnitProperty_MaximumFramesPerSlice, kAudioUnitScope_Global, 0, &maximum, &length);
        chain->chunk = MAX(1u, MIN(maximum, (UInt32)kSGTimePitchMaxFrames));
    }
    pthread_mutex_unlock(&sourceLocks[chain - sources]);
    pthread_mutex_unlock(&lock);
    if (!connection->sourceAudioUnit) {
        AURenderCallbackStruct callback = {0};
        SGAudioOriginalSetProperty(output, kAudioUnitProperty_SetRenderCallback, kAudioUnitScope_Input, 0, &callback, sizeof callback);
        return SGAudioOriginalSetProperty(output, property, scope, element, data, size);
    }
    AudioStreamBasicDescription sourceFormat = {0}, client = {0};
    UInt32 length = sizeof sourceFormat;
    OSStatus sourceRead = AudioUnitGetProperty(connection->sourceAudioUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Output, connection->sourceOutputNumber, &sourceFormat, &length);
    if (!sourceRead && readFormat(output, kAudioUnitScope_Input, &client) && sourceFormat.mFormatID == kAudioFormatLinearPCM &&
        isfinite(sourceFormat.mSampleRate) && sourceFormat.mSampleRate > 0 && sourceFormat.mChannelsPerFrame == client.mChannelsPerFrame && sourceFormat.mSampleRate != client.mSampleRate) {
        // RemoteIO must convert from the actual local-file mixer rate, not play it at the hardware rate.
        client.mSampleRate = sourceFormat.mSampleRate;
        SGAudioOriginalSetProperty(output, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Input, 0, &client, sizeof client);
    }
    AURenderCallbackStruct callback = {feed, chain};
    OSStatus status = SGAudioOriginalSetProperty(output, kAudioUnitProperty_SetRenderCallback, kAudioUnitScope_Input, 0, &callback, sizeof callback);
    if (status) {
        pthread_mutex_lock(&lock);
        pthread_mutex_lock(&sourceLocks[chain - sources]); chain->source = NULL; pthread_mutex_unlock(&sourceLocks[chain - sources]);
        pthread_mutex_unlock(&lock);
        return SGAudioOriginalSetProperty(output, property, scope, element, data, size);
    }
    configure(output, true);
    return noErr;
}
static void apply(BOOL rebuild) {
    pthread_mutex_lock(&lock);
    for (unsigned i = 0; i < 16; i++) {
        Source *chain = &sources[i];
        if (!chain->output) continue;
        pthread_mutex_lock(&sourceLocks[i]);
        if (rebuild) build(chain);
        SGTimePitch *unit = chain->source ? chain->pull : chain->inPlace;
        if (!unit) { pthread_mutex_unlock(&sourceLocks[i]); continue; }
        SGTimePitchSetRate(unit, chain->source ? speed : 1);
        SGTimePitchSetSemitones(unit, coupled ? 0 : semitones);
        BOOL wants = (chain->source && speed != 1) || (!coupled && semitones != 0);
        if (wants && !chain->engaged) { SGTimePitchReset(unit); chain->engaged = YES; }
        pthread_mutex_unlock(&sourceLocks[i]);
    }
    NSUInteger revision = ++change;
    pthread_mutex_unlock(&lock);
    if (speed == 1 && (coupled || semitones == 0)) dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 1500 * NSEC_PER_MSEC), dispatch_get_main_queue(), ^{
        pthread_mutex_lock(&lock);
        if (revision == change) for (unsigned i = 0; i < 16; i++) {
            pthread_mutex_lock(&sourceLocks[i]); sources[i].engaged = NO; pthread_mutex_unlock(&sourceLocks[i]);
        }
        pthread_mutex_unlock(&lock);
    });
}
double SGPlayerSpeed(void) { return speed; }
BOOL SGPlayerSpeedAllowed(void) {
    BOOL result = NO;
    pthread_mutex_lock(&lock);
    for (unsigned i = 0; i < 16; i++) if (sources[i].pull) result = YES;
    pthread_mutex_unlock(&lock);
    return result;
}
void SGSetPlayerSpeed(double value) {
    if (!isfinite(value) || value < 0.25 || value > 4 || !SGPlayerSpeedAllowed()) return;
    pthread_mutex_lock(&lock); speed = value; pthread_mutex_unlock(&lock);
    uint32_t bits; memcpy(&bits, &speed, sizeof bits); atomic_store(&speedBits, bits);
    apply(NO);
}
float SGPlayerPitch(void) { return semitones; }
BOOL SGPlayerPitchAvailable(void) { return available && !coupled; }
void SGSetPlayerPitch(float value) {
    if (!SGPlayerPitchAvailable() || !isfinite(value) || fabsf(value) > 24) return;
    pthread_mutex_lock(&lock); semitones = value; pthread_mutex_unlock(&lock); apply(NO);
}
BOOL SGPlayerPitchFollowsSpeed(void) { return coupled; }
void SGSetPlayerPitchFollowsSpeed(BOOL value) {
    pthread_mutex_lock(&lock); coupled = value; pthread_mutex_unlock(&lock);
    SGSetEnabled(SGKeyPitchFollowsSpeed, value); apply(YES);
}
%hook SPTPlayerState
- (double)playbackSpeed {
    uint32_t bits = atomic_load(&speedBits); float value; memcpy(&value, &bits, sizeof value);
    return %orig * value;
}
%end
%ctor {
    for (unsigned i = 0; i < 16; i++) pthread_mutex_init(&sourceLocks[i], NULL);
    coupled = SGFlag(SGKeyPitchFollowsSpeed, YES);
    uint32_t bits; memcpy(&bits, &speed, sizeof bits); atomic_store(&speedBits, bits);
    available = SGAudioRegister(SGAudioSpeed, configure, rendered, disconnect);
    if (available) SGAudioRegisterPropertyHandler(setProperty);
    %init;
    SGRequireClasses(@[@"SPTPlayerState"]);
}
