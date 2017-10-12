//
//  NullSafe.m
//
//  Version 1.2.2
//
//  Created by Nick Lockwood on 19/12/2012.
//  Copyright 2012 Charcoal Design
//
//  Distributed under the permissive zlib License
//  Get the latest version from here:
//
//  https://github.com/nicklockwood/NullSafe
//
//  This software is provided 'as-is', without any express or implied
//  warranty.  In no event will the authors be held liable for any damages
//  arising from the use of this software.
//
//  Permission is granted to anyone to use this software for any purpose,
//  including commercial applications, and to alter it and redistribute it
//  freely, subject to the following restrictions:
//
//  1. The origin of this software must not be misrepresented; you must not
//  claim that you wrote the original software. If you use this software
//  in a product, an acknowledgment in the product documentation would be
//  appreciated but is not required.
//
//  2. Altered source versions must be plainly marked as such, and must not be
//  misrepresented as being the original software.
//
//  3. This notice may not be removed or altered from any source distribution.
//

#import <objc/runtime.h>
#import <Foundation/Foundation.h>


#ifndef NULLSAFE_ENABLED
#define NULLSAFE_ENABLED 1
#endif


#pragma GCC diagnostic ignored "-Wgnu-conditional-omitted-operand"


@implementation NSNull (NullSafe)

#if NULLSAFE_ENABLED

- (NSMethodSignature *)methodSignatureForSelector:(SEL)selector
{
    @synchronized([self class])
    {
        //look up method signature
        NSMethodSignature *signature = [super methodSignatureForSelector:selector];
        if (!signature)
        {
            //not supported by NSNull, search other classes
            static NSMutableSet *classList = nil;
            static NSMutableDictionary *signatureCache = nil;
            if (signatureCache == nil)
            {
                classList = [[NSMutableSet alloc] init];
                signatureCache = [[NSMutableDictionary alloc] init];
                //get class list
//                int objc_getClassList(Class *buffer, int bufferCount)
//                分析：该函数的作用是获取已经注册的类，它需要传入两个参数，第一个参数 buffer ：已分配好内存空间的数组，第二个参数 bufferCount ：数组中可存放元素的个数，返回值是注册的类的总数。
//                当参数 bufferCount 值小于注册的类的总数时，获取到的是注册类的集合的任意子集
//                第一个参数传 NULL 时将会获取到当前注册的所有的类，此时可存放元素的个数为0，因此第二个参数可传0，返回值为当前注册的所有类的总数。
                int numClasses = objc_getClassList(NULL, 0);
                //函数malloc()在动态存储区中分配一块长度为size字节的连续区域，参数size为需要内存空间的长度，返回该区域的首地址
                Class *classes = (Class *)malloc(sizeof(Class) * (unsigned long)numClasses);
//                向已分配好内存空间的数组 classes 中存放元素，https://developer.apple.com/documentation/objectivec/1418579-objc_getclasslist
                numClasses = objc_getClassList(classes, numClasses);
                //add to list for checking
                //从所有注册的类中进行遍历，查找出直接继承于NSObject的类,并将含有子类的基类加到excluded这个集合中
                NSMutableSet *excluded = [NSMutableSet set];
                for (int i = 0; i < numClasses; i++)
                {
                    //determine if class has a superclass
                    Class someClass = classes[i];
                    Class superclass = class_getSuperclass(someClass);
                    while (superclass)
                    {
                        if (superclass == [NSObject class])
                        {
                            [classList addObject:someClass];
                            break;
                        }
                        [excluded addObject:NSStringFromClass(superclass)];
                        superclass = class_getSuperclass(superclass);
                    }
                }
                //remove all classes that have subclasses
                /*事实证明这个方法完全无用！！！纯属外国人坑爹！！！
                 我在想他原本的意思应该是这样的，将含有子类的类加到一个集合中，因为子类继承了父类的所有方法，所以说在下面判断是否类中含有实例方法的时候可以减少一下遍历的时间，然而他上一步却将字符串加到此集合中，导致在遍历移除的时候并不能移除对应的类
                 */
                for (Class someClass in excluded)
                {
                    [classList removeObject:someClass];
                }

                //free class list
                free(classes);
            }
            //check implementation cache first
            //从缓存中查找函数的签名
            NSString *selectorString = NSStringFromSelector(selector);
            signature = signatureCache[selectorString];
            if (!signature)
            {
                //find implementation
                for (Class someClass in classList)
                {
                    //类中是否包含实例方法，如果包含返回对应的函数签名
                    if ([someClass instancesRespondToSelector:selector])
                    {
                        signature = [someClass instanceMethodSignatureForSelector:selector];
                        break;
                    }
                }
                
                //cache for next time
                /*下面代码等效于 signatureCache[selectorString] = signature ? signature : [NSNull null];
                 将其放到静态变量中，一直保存便于下次查找
                 */
                signatureCache[selectorString] = signature ?: [NSNull null];
            }
            else if ([signature isKindOfClass:[NSNull class]])
            {
                signature = nil;
            }
        }
        return signature;
    }
}

- (void)forwardInvocation:(NSInvocation *)invocation
{
    //将其执行函数对象转为nil来执行，就不会崩溃了
    invocation.target = nil;
    [invocation invoke];
}

#endif

@end
