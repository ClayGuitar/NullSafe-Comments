//
//  ViewController.m
//  NullDemo
//
//  Created by aayongche on 2017/10/11.
//  Copyright © 2017年 AA租车. All rights reserved.
//

#import "ViewController.h"
#import <objc/runtime.h>

@interface Student : NSObject

- (void)say:(NSString *)saySomething;

@end

@implementation Student

- (void)say:(NSString *)saySomething {
    NSLog(@"Student Say:%@", saySomething);
}

@end

void dynamicMethodIMP(id self, SEL _cmd, NSString *saySomething) {
    NSLog(@"动态添加的方法:%@", saySomething);
}

@interface Teacher : NSObject

- (void)hello;

- (void)say:(NSString *)saySomething;

@end

@implementation Teacher

- (void)hello {
    NSLog(@"Teacher Hello");
}

+ (BOOL)resolveInstanceMethod:(SEL)sel {
    NSLog(@"resolveClassMethod called %@",NSStringFromSelector(sel));
    if (sel == @selector(say:)) {
        class_addMethod([self class], sel, (IMP)dynamicMethodIMP, "v@:@");
        return YES;
    }
    return [super resolveInstanceMethod:sel];
}

- (id)forwardingTargetForSelector:(SEL)aSelector {
    NSLog(@"forwardingTargetForSelector called %@",NSStringFromSelector(aSelector));
    if (aSelector == @selector(say:)) {
        return [Student new];
    }
    return [super forwardingTargetForSelector:aSelector];
}

- (NSMethodSignature *)methodSignatureForSelector:(SEL)aSelector {
    NSLog(@"methodSignatureForSelector called %@",NSStringFromSelector(aSelector));
    NSMethodSignature *methodSignature = [super methodSignatureForSelector:aSelector];
    if (!methodSignature) {
        if (aSelector == @selector(say:)) {
            methodSignature = [NSMethodSignature signatureWithObjCTypes:"v@:@"];
        }
    }
    return methodSignature;
}

- (void)forwardInvocation:(NSInvocation *)anInvocation {
    NSLog(@"forwardInvocation called %@",NSStringFromSelector(anInvocation.selector));
    Student *student = [Student new];
    if ([student respondsToSelector:anInvocation.selector]) {
        [anInvocation invokeWithTarget:student];
    }
}

@end

@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    Teacher *teacher = [Teacher new];
    [teacher hello];
    [teacher say:@"Teacher Stand"];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


@end
