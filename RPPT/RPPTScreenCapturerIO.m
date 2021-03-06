//
//  RPPTScreenCapturerIO.m
//  RPPT
//
//  Created by Andrew Finke on 12/12/17.
//  Copyright © 2017 aspin. All rights reserved.
//

#include <mach/mach.h>
#include <mach/mach_time.h>

#import "RPPTScreenCapturerIO.h"
#import "RPPT-Swift.h"

int const PreferredFPS = 10;
double const QualityFactor = 0.5;

/**

 Lab iPhone 6 Perf (queue max = 2):

 10 FPS:

 0.5 = 95% CPU;
 0.75 = 110% CPU;
 1.0 = 130% CPU; [Queue droping frames];

 20 FPS:

 0.5 = 140% CPU;
 0.75 = 145% CPU;  [Queue droping significant amount of frames];
 1.0 = 150% CPU; [Queue droping significant amount of frames];

 */



@interface UIWindow (Private)
- (IOSurfaceRef)createIOSurface;
@end

CGImageRef UICreateCGImageFromIOSurface(IOSurfaceRef ioSurface);

@implementation RPPTScreenCapturer {
    NSTimer *timer;

    CVPixelBufferRef _pixelBuffer;
    BOOL _capturing;
    OTVideoFrame* _videoFrame;

    NSOperationQueue *queue;
    UIWindow *window;
}

@synthesize videoCaptureConsumer;

#pragma mark - Class Lifecycle.

- (instancetype)init {
    self = [super init];
    if (self) {
        // Recommend sending 5 frames per second: Allows for higher image
        // quality per frame

        window = [(RPPTAppDelegate *)[[UIApplication sharedApplication] delegate] window];

        queue = [[NSOperationQueue alloc] init];
        [queue setMaxConcurrentOperationCount: 2];

        OTVideoFormat *format = [[OTVideoFormat alloc] init];
        [format setPixelFormat:OTPixelFormatARGB];

        _videoFrame = [[OTVideoFrame alloc] initWithFormat:format];
    }

    return self;
}

- (void)dealloc
{
    [self stopCapture];
    CVPixelBufferRelease(_pixelBuffer);
}

#pragma mark - Private Methods

/**
 * Make sure receiving video frame container is setup for this image.
 */
- (void)checkImageSize:(CGImageRef)image {
    CGFloat width = CGImageGetWidth(image);
    CGFloat height = CGImageGetHeight(image);

    if (_videoFrame.format.imageHeight == height &&
        _videoFrame.format.imageWidth == width)
    {
        // don't rock the boat. if nothing has changed, don't update anything.
        return;
    }

    [_videoFrame.format.bytesPerRow removeAllObjects];
    [_videoFrame.format.bytesPerRow addObject:@(width * 4)];
    [_videoFrame.format setImageHeight:height];
    [_videoFrame.format setImageWidth:width];

    CGSize frameSize = CGSizeMake(width, height);
    NSDictionary *options = [NSDictionary dictionaryWithObjectsAndKeys:
                             @NO,
                             kCVPixelBufferCGImageCompatibilityKey,
                             @NO,
                             kCVPixelBufferCGBitmapContextCompatibilityKey,
                             nil];

    if (NULL != _pixelBuffer) {
        CVPixelBufferRelease(_pixelBuffer);
    }

    CVReturn status = CVPixelBufferCreate(kCFAllocatorDefault,
                                          frameSize.width,
                                          frameSize.height,
                                          kCVPixelFormatType_32ARGB,
                                          (__bridge CFDictionaryRef)(options),
                                          &_pixelBuffer);

    NSParameterAssert(status == kCVReturnSuccess && _pixelBuffer != NULL);
}

#pragma mark - Capture lifecycle

/**
 * Allocate capture resources; in this case we're just setting up a timer and
 * block to execute periodically to send video frames.
 */
- (void)initCapture {
    timer = [NSTimer scheduledTimerWithTimeInterval:1.0 / PreferredFPS target:self selector:@selector(shouldCaptureFrame) userInfo:nil repeats:true];
}

-(void)shouldCaptureFrame {
    if (queue.operationCount > 10) {
        NSLog(@"Queue dropping frames");
        [queue cancelAllOperations];
    }
    [queue addOperationWithBlock:^{
        IOSurfaceRef surface = [window createIOSurface];
        CGImageRef ref = UICreateCGImageFromIOSurface(surface);
        CFRelease(surface);
        [self consumeFrame: ref];
    }];
}

- (void)releaseCapture {
    timer = nil;
}

- (int32_t)startCapture
{
    _capturing = YES;

    return 0;
}

- (int32_t)stopCapture
{
    _capturing = NO;

    [timer invalidate];

    return 0;
}

- (BOOL)isCaptureStarted
{
    return _capturing;
}

#pragma mark - Screen capture implementation

- (CVPixelBufferRef)pixelBufferFromCGImage:(CGImageRef)image
{
    CGFloat width = CGImageGetWidth(image);
    CGFloat height = CGImageGetHeight(image);
    CGSize frameSize = CGSizeMake(width, height);
    CVPixelBufferLockBaseAddress(_pixelBuffer, 0);
    void *pxdata = CVPixelBufferGetBaseAddress(_pixelBuffer);

    CGColorSpaceRef rgbColorSpace = CGColorSpaceCreateDeviceRGB();
    CGContextRef context =
    CGBitmapContextCreate(pxdata,
                          frameSize.width,
                          frameSize.height,
                          8,
                          CVPixelBufferGetBytesPerRow(_pixelBuffer),
                          rgbColorSpace,
                          kCGImageAlphaPremultipliedFirst |
                          kCGBitmapByteOrder32Little);


    CGContextDrawImage(context, CGRectMake(0, 0, width, height), image);
    CGColorSpaceRelease(rgbColorSpace);
    CGContextRelease(context);

    CVPixelBufferUnlockBaseAddress(_pixelBuffer, 0);

    return _pixelBuffer;
}

- (int32_t)captureSettings:(OTVideoFormat*)videoFormat
{
    videoFormat.pixelFormat = OTPixelFormatARGB;
    return 0;
}

+ (void)dimensionsForInputSize:(CGSize)input
                 containerSize:(CGSize*)destContainerSize
                      drawRect:(CGRect*)destDrawRect
{
    CGFloat sourceWidth = input.width;
    CGFloat sourceHeight = input.height;
    double sourceAspectRatio = sourceWidth / sourceHeight;

    CGFloat destContainerWidth = sourceWidth;
    CGFloat destContainerHeight = sourceHeight;
    CGFloat destImageWidth = sourceWidth;
    CGFloat destImageHeight = sourceHeight;

    // if image is wider than tall and width breaks edge size limit
    if (MAX_EDGE_SIZE_LIMIT < sourceWidth && sourceAspectRatio >= 1.0) {
        destContainerWidth = MAX_EDGE_SIZE_LIMIT;
        destContainerHeight = destContainerWidth / sourceAspectRatio;
        if (0 != fmod(destContainerHeight, EDGE_DIMENSION_COMMON_FACTOR)) {
            // add padding to make height % 16 == 0
            destContainerHeight +=
            (EDGE_DIMENSION_COMMON_FACTOR - fmod(destContainerHeight,
                                                 EDGE_DIMENSION_COMMON_FACTOR));
        }
        destImageWidth = destContainerWidth;
        destImageHeight = destContainerWidth / sourceAspectRatio;
    }

    // if image is taller than wide and height breaks edge size limit
    if (MAX_EDGE_SIZE_LIMIT < destContainerHeight && sourceAspectRatio <= 1.0) {
        destContainerHeight = MAX_EDGE_SIZE_LIMIT;
        destContainerWidth = destContainerHeight * sourceAspectRatio;
        if (0 != fmod(destContainerWidth, EDGE_DIMENSION_COMMON_FACTOR)) {
            // add padding to make width % 16 == 0
            destContainerWidth +=
            (EDGE_DIMENSION_COMMON_FACTOR - fmod(destContainerWidth,
                                                 EDGE_DIMENSION_COMMON_FACTOR));
        }
        destImageHeight = destContainerHeight;
        destImageWidth = destContainerHeight * sourceAspectRatio;
    }

    // ensure the dimensions of the resulting container are safe
    if (fmod(destContainerWidth, EDGE_DIMENSION_COMMON_FACTOR) != 0) {
        double remainder = fmod(destContainerWidth,
                                EDGE_DIMENSION_COMMON_FACTOR);
        // increase the edge size only if doing so does not break the edge limit
        if (destContainerWidth + (EDGE_DIMENSION_COMMON_FACTOR - remainder) >
            MAX_EDGE_SIZE_LIMIT)
        {
            destContainerWidth -= remainder;
        } else {
            destContainerWidth += EDGE_DIMENSION_COMMON_FACTOR - remainder;
        }
    }
    // ensure the dimensions of the resulting container are safe
    if (fmod(destContainerHeight, EDGE_DIMENSION_COMMON_FACTOR) != 0) {
        double remainder = fmod(destContainerHeight,
                                EDGE_DIMENSION_COMMON_FACTOR);
        // increase the edge size only if doing so does not break the edge limit
        if (destContainerHeight + (EDGE_DIMENSION_COMMON_FACTOR - remainder) >
            MAX_EDGE_SIZE_LIMIT)
        {
            destContainerHeight -= remainder;
        } else {
            destContainerHeight += EDGE_DIMENSION_COMMON_FACTOR - remainder;
        }
    }

    destContainerSize->width = destContainerWidth;
    destContainerSize->height = destContainerHeight;

    // scale and recenter source image to fit in destination container
    if (sourceAspectRatio > 1.0) {
        destDrawRect->origin.x = 0;
        destDrawRect->origin.y =
        (destContainerHeight - destImageHeight) / 2;
        destDrawRect->size.width = destContainerWidth;
        destDrawRect->size.height =
        destContainerWidth / sourceAspectRatio;
    } else {
        destDrawRect->origin.x =
        (destContainerWidth - destImageWidth) / 2;
        destDrawRect->origin.y = 0;
        destDrawRect->size.height = destContainerHeight;
        destDrawRect->size.width =
        destContainerHeight * sourceAspectRatio;
    }

}

- (void) consumeFrame:(CGImageRef)sourceCGImage {
    CGFloat sourceWidth = CGImageGetWidth(sourceCGImage) * QualityFactor;
    CGFloat sourceHeight = CGImageGetHeight(sourceCGImage) * QualityFactor;
    CGSize sourceSize = CGSizeMake(sourceWidth, sourceHeight);
    CGSize destContainerSize = CGSizeZero;
    CGRect destRectForSourceImage = CGRectZero;

    [RPPTScreenCapturer dimensionsForInputSize:sourceSize
                                 containerSize:&destContainerSize
                                      drawRect:&destRectForSourceImage];

    CGImageRef frame = NULL;
    @autoreleasepool {
        CGContextRef context = CGBitmapContextCreate(nil,
                                                     destContainerSize.width,
                                                     destContainerSize.height,
                                                     CGImageGetBitsPerComponent(sourceCGImage),
                                                     CGImageGetBytesPerRow(sourceCGImage),
                                                     CGImageGetColorSpace(sourceCGImage),
                                                     CGImageGetBitmapInfo(sourceCGImage));

        CGContextSetInterpolationQuality(context, kCGInterpolationNone);
        CGContextDrawImage(context, destRectForSourceImage, sourceCGImage);

        frame = CGBitmapContextCreateImage(context);
        CGContextRelease(context);
    }
    CGImageRelease(sourceCGImage);

    [self checkImageSize:frame];

    static mach_timebase_info_data_t time_info;
    uint64_t time_stamp = 0;

    if (!(_capturing && self.videoCaptureConsumer)) {
        return;
    }

    if (time_info.denom == 0) {
        (void) mach_timebase_info(&time_info);
    }

    time_stamp = mach_absolute_time();
    time_stamp *= time_info.numer;
    time_stamp /= time_info.denom;

    CMTime time = CMTimeMake(time_stamp, 1000);
    CVImageBufferRef ref = [self pixelBufferFromCGImage:frame];

    CVPixelBufferLockBaseAddress(ref, 0);

    _videoFrame.timestamp = time;
    _videoFrame.format.estimatedFramesPerSecond = PreferredFPS;
    _videoFrame.orientation = OTVideoOrientationUp;

    [_videoFrame clearPlanes];
    [_videoFrame.planes addPointer:CVPixelBufferGetBaseAddress(ref)];
    [self.videoCaptureConsumer consumeFrame:_videoFrame];

    CVPixelBufferUnlockBaseAddress(ref, 0);

    CGImageRelease(frame);
}

@end
