//
//  RPPTScreenCapturerIO.m
//  RPPT
//
//  Created by Andrew Finke on 12/12/17.
//  Copyright © 2017 aspin. All rights reserved.
//

#include <mach/mach.h>
#include <mach/mach_time.h>
#import "AppDelegate.h"
#import "RPPTScreenCapturerIO.h"
@import Metal;

@import UIKit;

int const PreferredFPS = 20;

/** Inversely related to performance

 Lab iPhone Perf:

 10 FPS:

 0.5 = 95% CPU;
 0.75 = 110% CPU;
 1.0 = 130% CPU; [Queue droping frames];

 20 FPS:

 0.5 = 140% CPU;
 0.75 = 145% CPU;  [Queue droping significant amount of frames];
 1.0 = 150% CPU; [Queue droping significant amount of frames];

 */
double const QualityFactor = 0.75;

@interface UIWindow (Private)
- (IOSurfaceRef)createIOSurface;
@end

CGImageRef UICreateCGImageFromIOSurface(IOSurfaceRef ioSurface);

@implementation RPPTScreenCapturer {
    NSTimer *timer;

    CVPixelBufferRef _pixelBuffer;
    BOOL _capturing;

    NSOperationQueue *queue;
    UIWindow *window;

    CIContext *bufferContext;
}

#pragma mark - Class Lifecycle.

- (instancetype)init {
    self = [super init];
    if (self) {
        // Recommend sending 5 frames per second: Allows for higher image
        // quality per frame

        bufferContext = [CIContext contextWithMTLDevice:MTLCreateSystemDefaultDevice() options: @{
                                                         kCIContextUseSoftwareRenderer: @(NO),
                                                         kCIImageColorSpace: [NSNull null]
                                                         }];

        queue = [[NSOperationQueue alloc] init];
        [queue setMaxConcurrentOperationCount: 20];

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
        NSLog(@"This is very bad");
        [queue cancelAllOperations];
    }
    [queue addOperationWithBlock:^{
        CGSize imageSize = CGSizeZero;

        imageSize = [UIScreen mainScreen].bounds.size;

        UIGraphicsBeginImageContextWithOptions(imageSize, NO, 0);
        UIWindow *window = [UIApplication sharedApplication].keyWindow;

        if ([window respondsToSelector:
             @selector(drawViewHierarchyInRect:afterScreenUpdates:)])
        {
            [window drawViewHierarchyInRect:window.bounds afterScreenUpdates:NO];
        }
        else {
            [window.layer renderInContext:UIGraphicsGetCurrentContext()];
        }

        UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();

         @autoreleasepool {
        CIImage *a = [[CIImage alloc] initWithImage:image];
        [self consumeFrame: a];
             
         }
        
//
//        if (surface != NULL) {
//            CIImage *image = [[CIImage alloc] initWithIOSurface:surface];
//            CFRelease(surface);
//            [self consumeFrame: image];
//        } else {
//
//        }

    }];
}

- (void)releaseCapture {
    timer = nil;
}

- (int32_t)startCapture
{
    _capturing = YES;

    window = [(AppDelegate*)[[UIApplication sharedApplication] delegate] window];

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

- (void) consumeFrame:(CIImage* )sourceImage {
    CGFloat sourceWidth = CGRectGetWidth([sourceImage extent]);
    CGFloat sourceHeight = CGRectGetHeight([sourceImage extent]);
    CGSize sourceSize = CGSizeMake(sourceWidth, sourceHeight);
    CGSize destContainerSize = CGSizeZero;
    CGRect destRectForSourceImage = CGRectZero;


    [RPPTScreenCapturer dimensionsForInputSize:sourceSize
                                 containerSize:&destContainerSize
                                      drawRect:&destRectForSourceImage];
    CIImage *result = NULL;
    @autoreleasepool {

        CIFilter *resizeFilter = [CIFilter filterWithName:@"CILanczosScaleTransform"];
        [resizeFilter setValue:sourceImage forKey:@"inputImage"];
        [resizeFilter setValue:[NSNumber numberWithFloat:1.0f] forKey:@"inputAspectRatio"];
        [resizeFilter setValue:[NSNumber numberWithFloat:QualityFactor * destContainerSize.width / sourceSize.width] forKey:@"inputScale"];

        CIFilter *cropFilter = [CIFilter filterWithName:@"CICrop"];

        CIVector *cropRect = [CIVector vectorWithX:destRectForSourceImage.origin.x Y:destRectForSourceImage.origin.y Z:destRectForSourceImage.size.width W:destRectForSourceImage.size.height];
        [cropFilter setValue:resizeFilter.outputImage forKey:@"inputImage"];
        [cropFilter setValue:cropRect forKey:@"inputRectangle"];
        CIImage *croppedImage = cropFilter.outputImage;

        result = [croppedImage imageByCroppingToRect:destRectForSourceImage];

        [resizeFilter setValue:nil forKey:@"inputImage"];
        [cropFilter setValue:nil forKey:@"inputImage"];
    }


    CGSize size = result.extent.size;
    CVPixelBufferRef ref = NULL;


    dispatch_queue_t dqueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0);

    dispatch_async(dqueue, ^{

        CVPixelBufferCreate(kCFAllocatorDefault,
                            size.width,
                            size.height,
                            kCVPixelFormatType_32ARGB,
                            (__bridge CFDictionaryRef) @{(__bridge NSString *) kCVPixelBufferIOSurfacePropertiesKey: @{}},
                            &ref);

        [bufferContext render:result toCVPixelBuffer:ref];

        CVPixelBufferRelease(ref);
        NSLog(@"%lu",(unsigned long)[queue operationCount]);
    });


//    CVPixelBufferLockBaseAddress(_pixelBuffer, 0);
//
//    CVPixelBufferUnlockBaseAddress(_pixelBuffer, 0);
}

@end

