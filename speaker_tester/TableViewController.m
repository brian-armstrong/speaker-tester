#import "TableViewController.h"

#import <AVFoundation/AVFoundation.h>

@interface TableViewController()
@property NSArray *cells;
@property NSInteger channels;
@property NSString *uid;
@property bool started;
@property int playSide;
@property float phase;
@end

static const unsigned int bufferLength = 4096;
static const float freq = 2 * M_PI * (440.f / 44100.f);
static const float amp = 0.1f;

static void output_callback(void *user_data, AudioQueueRef queue, AudioQueueBufferRef buffer)
{
  float *stereo = (float *)buffer->mAudioData;
  TableViewController *controller = (__bridge id)user_data;
  memset(stereo, 0, buffer->mAudioDataBytesCapacity);
  const int playSide = [controller playSide];
  float phase = [controller phase];
  for (unsigned int i = 0; i < bufferLength; i++) {
    if (playSide == -1 || playSide == 0) {
      stereo[2 * i] = amp * sinf(phase);
    }
    if (playSide == -1 || playSide == 1) {
      stereo[(2 * i) + 1] = amp * sinf(phase);
    }
    phase += freq;
    if (phase > 2 * M_PI) {
      phase -= 2 * M_PI;
    }
  }
  [controller setPhase:phase];
  buffer->mAudioDataByteSize = buffer->mAudioDataBytesCapacity;
  AudioQueueEnqueueBuffer(queue, buffer, 0, NULL);
}

@implementation TableViewController {
  AudioQueueRef outputQueue;
  AudioQueueBufferRef *outputBuffers;
}

- (void)loadView
{
  [super loadView];
  
  self.title = @"Speaker Test";
  
  NSMutableArray *labels = [NSMutableArray arrayWithObjects:@"Stereo, Left Only", @"Stereo, Right Only", @"Pan Left", @"Pan Right", nil];
  
  NSArray *outputs = AVAudioSession.sharedInstance.currentRoute.outputs;
  self.channels = 0;
  if ([outputs count] > 0) {
    AVAudioSessionPortDescription *port = outputs[0];
    NSArray *channels = port.channels;
    for (int j = 0; j < [channels count]; ++j) {
      AVAudioSessionChannelDescription *channel = channels[j];
      [labels addObject:[NSString stringWithFormat:@"%@/%@", [port portName], [channel channelName]]];
    }
    self.channels = [channels count];
    self.uid = [channels[0] owningPortUID];
  }
  
  NSMutableArray *mutCells = [NSMutableArray arrayWithCapacity:16];
  
  for (int i = 0; i < [labels count]; ++i) {
    UITableViewCell *cell = [[UITableViewCell alloc] init];
    UILabel *label = [[UILabel alloc] initWithFrame:CGRectInset(cell.bounds, 15, 0)];
    label.text = labels[i];
    [cell addSubview:label];
    [mutCells addObject:cell];
  }
  
  self.cells = mutCells;

  self.started = false;
  self.playSide = -1;
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
  return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
  if (section == 0) {
    return [self.cells count];
  }
  return 0;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
  if (indexPath.section == 0) {
    return self.cells[indexPath.row];
  }
  return nil;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
  return nil;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
  if (indexPath.section != 0) {
    return;
  }
  
  if (self.started) {
    AudioQueueReset(outputQueue);
    AudioQueueDispose(outputQueue, true);
  }

  AudioStreamBasicDescription format;
  format.mSampleRate = 44100.f;
  format.mFormatID = kAudioFormatLinearPCM;
  format.mFormatFlags = kAudioFormatFlagIsFloat | kAudioFormatFlagIsPacked;
  format.mBitsPerChannel = sizeof(float) * 8;
  format.mChannelsPerFrame = 2;
  format.mBytesPerFrame = sizeof(float) * format.mChannelsPerFrame;
  format.mFramesPerPacket = 1;
  format.mBytesPerPacket = format.mBytesPerFrame * format.mFramesPerPacket;
  format.mReserved = 0;
  
  AudioQueueNewOutput(&format, output_callback, (__bridge void *_Nullable)(self), NULL, NULL, 0, &outputQueue);
  
  if (indexPath.row == 0) {
    self.playSide = 0;
  } else if (indexPath.row == 1) {
    self.playSide = 1;
  } else {
    self.playSide = -1;
  }
  
  if (indexPath.row == 2) {
    AudioQueueSetParameter(outputQueue, kAudioQueueParam_Pan, -1);
  } else if (indexPath.row == 3) {
    AudioQueueSetParameter(outputQueue, kAudioQueueParam_Pan, 1);
  } else {
    AudioQueueSetParameter(outputQueue, kAudioQueueParam_Pan, 0);
  }
  
  if (indexPath.row > 3 && indexPath.row < (4 + self.channels)) {
    AudioQueueChannelAssignment assignments[2];
    assignments[0].mChannelNumber = (unsigned int)(indexPath.row - 3);
    assignments[0].mDeviceUID = (__bridge CFStringRef)self.uid;
    assignments[1].mChannelNumber = (unsigned int)(indexPath.row - 3);
    assignments[1].mDeviceUID = (__bridge CFStringRef)self.uid;
    AudioQueueSetProperty(outputQueue, kAudioQueueProperty_ChannelAssignments, assignments, sizeof(assignments));
  }

  outputBuffers = malloc(3 * sizeof(AudioQueueBufferRef));
  
  for (unsigned int i = 0; i < 3; i++) {
    AudioQueueAllocateBuffer(outputQueue, bufferLength * 2 * sizeof(float), &outputBuffers[i]);
    outputBuffers[i]->mAudioDataByteSize = bufferLength * 2 * sizeof(float);
    output_callback((__bridge void*)(self), outputQueue, outputBuffers[i]);
  }
  
  AudioQueueStart(outputQueue, NULL);
  
  self.started = true;
}

@end
