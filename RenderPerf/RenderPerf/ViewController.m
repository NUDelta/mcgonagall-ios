//
//  ViewController.m
//  RenderPerf
//
//  Created by Andrew Finke on 2/23/18.
//  Copyright © 2018 Andrew Finke. All rights reserved.
//

#import "ViewController.h"
#import "RPPTScreenCapturerIO.h"

@interface ViewController () {
    RPPTScreenCapturer *capture;
}

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    UILabel *label = [[UILabel alloc] initWithFrame:self.view.frame];
    [label setTextAlignment:NSTextAlignmentCenter];
//    [label setTextColor:[UIColor whiteColor]];
//    [label setText:@"Hi Meg!"];
    [label setFont:[UIFont systemFontOfSize:37 weight:UIFontWeightSemibold]];
    [self.view addSubview:label];

    __block NSInteger num = 0;

    [NSTimer scheduledTimerWithTimeInterval:1.0 / 30.0 repeats:true block:^(NSTimer * _Nonnull timer) {
        num += 1;
        CGFloat hue = ( arc4random() % 256 / 256.0 );  //  0.0 to 1.0
        CGFloat saturation = ( arc4random() % 128 / 256.0 ) + 0.5;  //  0.5 to 1.0, away from white
        CGFloat brightness = ( arc4random() % 128 / 256.0 ) + 0.5;  //  0.5 to 1.0, away from black
        UIColor *color = [UIColor colorWithHue:hue saturation:saturation brightness:brightness alpha:1];
        dispatch_async(dispatch_get_main_queue(), ^{
           [label setText:[NSString stringWithFormat:@"%ld", (long)num]];
        });
    }];

    // Do any additional setup after loading the view, typically from a nib.
}

- (void) viewDidAppear:(BOOL)animated {
    capture = [[RPPTScreenCapturer alloc] init];
    [capture initCapture];
    [capture startCapture];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


@end
