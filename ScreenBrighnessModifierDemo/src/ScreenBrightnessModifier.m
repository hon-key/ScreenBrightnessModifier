//  Copyright (c) 2019 HJ-Cai
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in all
//  copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
//  SOFTWARE.

#import "ScreenBrightnessModifier.h"
#import <objc/runtime.h>

static CGFloat bm_target_brightness;

static dispatch_queue_t bm_get_brightness_setting_queue() {
    static dispatch_queue_t queue;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        queue = dispatch_queue_create("com.brightness.modifier.queue", DISPATCH_QUEUE_SERIAL);
    });
    return queue;
}

static dispatch_semaphore_t bm_get_brightness_setting_semaphore() {
    static dispatch_semaphore_t sem;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sem = dispatch_semaphore_create(1);
    });
    return sem;
}

static void bm_brightness_setting_lock() {
    dispatch_semaphore_wait(bm_get_brightness_setting_semaphore(), DISPATCH_TIME_FOREVER);
}

static void bm_brightness_setting_unlock() {
    dispatch_semaphore_signal(bm_get_brightness_setting_semaphore());
}

static void bm_dispatch_should_keep_running(dispatch_source_t source,BOOL resume) {
    static BOOL suspended = YES;
    bm_brightness_setting_lock();
    if (resume) {
        if (suspended) {
            suspended = NO;
            dispatch_resume(source);
        }
    }else {
        if (!suspended) {
            suspended = YES;
            dispatch_suspend(source);
        }
    }
    bm_brightness_setting_unlock();
}

static dispatch_source_t get_brightness_modifier_source() {
    static dispatch_source_t source;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        source = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, bm_get_brightness_setting_queue());
        dispatch_source_set_timer(source, DISPATCH_TIME_NOW, ScreenBrightnessModifier.timeInterval * NSEC_PER_SEC, 0 * NSEC_PER_SEC);
        dispatch_source_set_event_handler(source, ^{
            
            CGFloat curBrightness = round([UIScreen mainScreen].brightness * 1000) / 1000;
            bm_target_brightness = round(bm_target_brightness * 1000) / 1000;
            if (curBrightness < bm_target_brightness) {
                
                curBrightness += ScreenBrightnessModifier.segment;
                if (curBrightness > bm_target_brightness) {
                    curBrightness = bm_target_brightness;
                }
                
            }else if (curBrightness > bm_target_brightness) {
                
                curBrightness -= ScreenBrightnessModifier.segment;
                if (curBrightness < bm_target_brightness) {
                    curBrightness = bm_target_brightness;
                }
                
            }else {
                bm_dispatch_should_keep_running(get_brightness_modifier_source(), NO);
                return;
            }
            
            [UIScreen mainScreen].brightness = curBrightness;
            NSLog(@"setBrightness:%f",curBrightness);
            
        });
    });
    return source;
}

@implementation ScreenBrightnessModifier

+ (CGFloat)timeInterval {
    return ((NSNumber *)objc_getAssociatedObject(self, _cmd)).doubleValue;
}

+ (void)setTimeInterval:(CGFloat)timeInterval {
    objc_setAssociatedObject(self, @selector(timeInterval), @(timeInterval), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    dispatch_source_set_timer(get_brightness_modifier_source(), DISPATCH_TIME_NOW, ScreenBrightnessModifier.timeInterval * NSEC_PER_SEC, 0 * NSEC_PER_SEC);
}

+ (CGFloat)segment {
    return ((NSNumber *)objc_getAssociatedObject(self, _cmd)).doubleValue;
}

+ (void)setSegment:(CGFloat)segment {
    objc_setAssociatedObject(self, @selector(segment), @(segment), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

+ (void)setBrightness:(CGFloat)value {
    bm_dispatch_should_keep_running(get_brightness_modifier_source(), NO);
    bm_target_brightness = value;
    bm_dispatch_should_keep_running(get_brightness_modifier_source(), YES);
}

@end
